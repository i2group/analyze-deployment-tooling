#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2023)
#
# SPDX short identifier: MIT

###############################################################################
# Function definitions start here                                             #
###############################################################################

#######################################
# This function will print out the usage for the script.
# Requires the `USAGE` variable to be set in the script.
# Arguments:
#   1. Exit code
#######################################
function print_usage() {
  local exit_code="$1"

  echo -e "${USAGE}"

  if [[ -n "${exit_code}" ]]; then
    exit "${exit_code}"
  fi
}

#######################################
# This function will parse common arguments.
# Arguments:
#   1. Argument
#######################################
function parse_common_arguments() {
  case "$1" in
  v)
    VERBOSE="true"
    ;;
  y)
    YES_FLAG="true"
    ;;
  h)
    print_usage 0
    ;;
  *)
    return 1
    ;;
  esac
}

#######################################
# This function will OPTIONS (short arguments) for the parsing CLI arguments.
# Requires `OPTIONS_FOR` variable to be set. Supported values:
#   createDevEnv, deploy, manageData, manageEnv, manageToolkitConfig,
#   buildConnectorImages, build_extensions, build_plugins, buildImages, generateSecrets,
#   createChangeSet, createConfiguration, createEnvironment
# Arguments:
#   None
#######################################
function set_options() {
  case "${OPTIONS_FOR}" in
  "createDevEnv")
    OPTIONS="vhy"
    ;;
  "deploy")
    OPTIONS="c:t:b:vhy"
    ;;
  "manageData")
    OPTIONS="c:t:d:s:vhy"
    ;;
  "manageEnv")
    OPTIONS="t:b:i:e:p:vhy"
    ;;
  "manageToolkitConfig")
    OPTIONS="c:t:n:vhy"
    ;;
  "buildConnectorImages")
    OPTIONS="i:e:vhy"
    ;;
  "build_extensions") ;&
    # Fallthrough
  "build_plugins")
    OPTIONS="c:i:e:vhy"
    ;;
  "buildImages") ;&
    # Fallthrough
  "createEnvironment") ;&
    # Fallthrough
  "createConfiguration")
    OPTIONS="e:vhy"
    ;;
  "createChangeSet")
    OPTIONS="c:t:e:n:vhy"
    ;;
  "generateSecrets")
    OPTIONS="c:t:i:e:vhy"
    ;;
  "manageConfig")
    OPTIONS="t:vhy"
    ;;
  "configurePaths")
    # cspell:disable-next-line
    OPTIONS="t:p:n:dvhy"
    ;;
  *)
    print_error_and_exit "OPTIONS_FOR is not set"
    ;;
  esac
}

#######################################
# This function will parse all arguments.
# Requires `OPTIONS_FOR` variable to be set.
# Arguments:
#   All arguments that were passed to the script ($@).
#######################################
function parse_arguments() {
  # Set options based on the script
  set_options
  # Parse all arguments
  while getopts "${OPTIONS}" flag; do
    # Parse common common arguments (-v, -y, -h flags)
    if ! parse_common_arguments "${flag}"; then
      # if arguments is not common parse them here
      case "${flag}" in
      c)
        if [[ "${OPTIONS_FOR}" == "generateSecrets" ]]; then
          COMPONENTS="${OPTARG}"
        else
          CONFIG_NAME="${OPTARG}"
        fi
        ;;
      t)
        if [[ "${OPTIONS_FOR}" == "createChangeSet" ]]; then
          TYPE="${OPTARG}"
        else
          TASK="${OPTARG}"
        fi
        ;;
      d)
        if [[ "${OPTIONS_FOR}" == "configurePaths" ]]; then
          DELETE_PATH_FLAG="true"
        else
          DATA_SET="${OPTARG}"
        fi
        ;;
      s)
        SCRIPT_NAME="${OPTARG}"
        ;;
      n)
        if [[ "${OPTIONS_FOR}" == "createChangeSet" ]]; then
          CHANGE_SET_NUMBER="${OPTARG}"
        elif [[ "${OPTIONS_FOR}" == "configurePaths" || "${OPTIONS_FOR}" == "manageToolkitConfig" ]]; then
          PATH_NAME="${OPTARG}"
        fi
        ;;
      b)
        BACKUP_NAME="${OPTARG}"
        ;;
      i)
        INCLUDED_ASSETS+=("${OPTARG}")
        ;;
      e)
        if [[ "${OPTIONS_FOR}" == "buildImages" || "${OPTIONS_FOR}" == "createChangeSet" ||
          "${OPTIONS_FOR}" == "createEnvironment" || "${OPTIONS_FOR}" == "createConfiguration" ]]; then
          ENVIRONMENT="${OPTARG}"
        else
          EXCLUDED_ASSETS+=("${OPTARG}")
        fi
        ;;
      p)
        if [[ "${OPTIONS_FOR}" == "manageEnv" ]]; then
          PREVIOUS_PROJECT_PATH="${OPTARG}"
        elif [[ "${OPTIONS_FOR}" == "configurePaths" ]]; then
          PATH_TO_DIR="${OPTARG}"
        fi
        ;;
      \?)
        print_usage 0
        ;;
      :)
        echo "Invalid option: ${OPTARG} requires an argument"
        ;;
      esac
    fi
  done
}

function start_container() {
  local container_name_or_id="$1"
  local container_id
  local container_name
  local max_retries=10

  # identify if name or id supplied as $1 exists
  container_id="$(docker ps -aq -f network="${DOMAIN_NAME}" -f name="^${container_name_or_id}$")"
  if [[ -z "${container_id}" ]]; then
    container_id="$(docker ps -aq -f network="${DOMAIN_NAME}" -f id="${container_name_or_id}")"
    if [[ -z "${container_id}" ]]; then
      print_info "${container_name_or_id} does NOT exist"
      return 0
    fi
  fi
  container_name="$(docker ps -a --format "{{.Names}}" -f id="${container_id}")"
  container_status="$(docker ps -a --format "{{.Status}}" -f name="^${container_name}$")"
  if [[ "${container_status}" != "Up" ]]; then
    print "Starting ${container_name} container"
    while ! docker start "${container_name_or_id}"; do
      if (("${max_retries}" == 0)); then
        print_error_and_exit "Unable to stop container '${container_name}', exiting script"
      else
        echo "[WARN] Having issues stopping container '${container_name}', retrying..."
        ((max_retries = "${max_retries}" - 1))
      fi
      sleep 1s
    done
  fi
}

function delete_container() {
  local container_name_or_id="$1"
  local container_id
  local container_name
  local max_retries=10

  # identify if name or id supplied as $1 exists
  container_id="$(docker ps -aq -f network="${DOMAIN_NAME}" -f name="^${container_name_or_id}$")"
  if [[ -z "${container_id}" ]]; then
    container_id="$(docker ps -aq -f network="${DOMAIN_NAME}" -f id="${container_name_or_id}")"
    if [[ -z "${container_id}" ]]; then
      print_info "${container_name_or_id} does NOT exist"
      return 0
    fi
  fi
  container_name="$(docker ps -aq --format "{{.Names}}" -f id="${container_id}")"
  print "Stopping ${container_name} container"
  while ! docker stop "${container_name_or_id}"; do
    if ((max_retries == 0)); then
      print_error_and_exit "Unable to stop container '${container_name}', exiting script"
    else
      echo "[WARN] Having issues stopping container '${container_name}', retrying..."
      max_retries=$((max_retries - 1))
    fi
    sleep 1s
  done
  print "Deleting ${container_name} container"
  docker rm "${container_name_or_id}"
}

function force_delete_container() {
  local container_name_or_id="$1"

  docker rm -f "${container_name_or_id}" &>/dev/null
}

function check_file_exists() {
  local file_path="$1"

  if [[ ! -f "${file_path}" ]]; then
    print_error_and_exit "File does NOT exist: ${file_path}"
  fi
}

function check_deployment_is_live() {
  local config_name="$1"
  local live_flag="true"
  local container_names=("${ZK1_CONTAINER_NAME}" "${SOLR1_CONTAINER_NAME}" "${LIBERTY1_CONTAINER_NAME}")

  if [[ "${DEPLOYMENT_PATTERN}" == *"store"* ]]; then
    case "${DB_DIALECT}" in
    db2)
      container_names+=("${DB2_SERVER_CONTAINER_NAME}")
      ;;
    sqlserver)
      container_names+=("${SQL_SERVER_CONTAINER_NAME}")
      ;;
    postgres)
      container_names+=("${POSTGRES_SERVER_CONTAINER_NAME}")
      ;;
    esac
  fi

  print "Checking '${config_name}' deployment is live"
  for container_name in "${container_names[@]}"; do
    local container_id
    container_id="$(docker ps -a -q -f network="${DOMAIN_NAME}" -f name="${container_name}" -f "status=running")"
    if [[ -z "${container_id}" ]]; then
      live_flag="false"
      print_info "${container_id} is not in the 'running' state"
    fi
  done
  if [[ "${live_flag}" == "false" ]]; then
    print_error_and_exit "Deployment is NOT live"
  else
    echo "Deployment is live"
  fi
}

function clear_liberty_validation_log() {
  docker exec "${LIBERTY1_CONTAINER_NAME}" bash -c 'echo "" >/logs/opal-services/i2_Validation.log'
  docker exec "${LIBERTY1_CONTAINER_NAME}" bash -c 'echo "" >/logs/opal-services/i2_Status.log'
}

function replace_xml_element_with_here_doc() {
  local xml_element="$1"
  local heredoc_file_path="$2"
  local log4j2_file_path="$3"
  # replace string with contents of a heredoc file, sed explanation:
  # line 1: when you find ${xml_element}
  # line 2: remove ${xml_element}
  # line 3: replace with the content of a file
  # line 4: delete the extra new line
  sed -i "/${xml_element}/{
          s/${xml_element}//g
          r ${heredoc_file_path}
          d
  }" "${log4j2_file_path}"
}

function append_logging_xml_element_with_here_doc() {
  local loggers_name="$1"
  local loggers_heredoc_file_path="$2"
  local loggers_level="$3"
  local loggers_appender_ref="$4"
  local tmp_log4j2_file_path="/tmp/log4j2.xml"

  if grep -q -E -o -m 1 "${loggers_name}" <"${tmp_log4j2_file_path}"; then
    # Force set logging level
    sed -i -E "s~(${loggers_name} level=\")[^\"]+~\1${loggers_level}~g" "${tmp_log4j2_file_path}"
    # Append AppenderRef for logger
    sed -i -E "/${loggers_name}/a \      <AppenderRef ref=\"${loggers_appender_ref}\" \/>" "${tmp_log4j2_file_path}"
  else
    replace_xml_element_with_here_doc "<\/Loggers>" "${loggers_heredoc_file_path}" "${tmp_log4j2_file_path}"
  fi
}

function add_config_admin() {
  print_info "Adding config dev environment administrator user to the system"
  add_config_admin_to_user_registry
  add_config_admin_to_command_access_control
  add_config_admin_to_server_xml
}

function add_config_admin_to_security_schema() {
  local security_schema_file_path="${GENERATED_LOCAL_CONFIG_DIR}/security-schema.xml"
  local security_schema_container_path="/config/apps/opal-services.war/WEB-INF/classes"
  local security_dimension_ids dimension_id
  local security_dimension_values dimension_value
  declare -A security_value_map

  readarray -t security_dimension_ids < <(xmlstarlet sel -t -v "/tns:SecuritySchema/SecurityDimensions/AccessSecurityDimensions/Dimension/@Id" "${security_schema_file_path}")
  for dimension_id in "${security_dimension_ids[@]}"; do
    readarray -t security_dimension_values < <(xmlstarlet sel -t -v "/tns:SecuritySchema/SecurityDimensions/AccessSecurityDimensions/Dimension[@Id='${dimension_id}']/DimensionValue/@Id" "${security_schema_file_path}")
    security_value_map["${dimension_id}"]="${security_dimension_values[*]}"
  done

  xmlstarlet edit -L \
    --subnode "/tns:SecuritySchema/SecurityPermissions" --type elem -n "GroupPermissions" \
    --insert "/tns:SecuritySchema/SecurityPermissions/GroupPermissions[last()]" --type attr -n "UserGroup" --value "${I2_ANALYZE_ADMIN}" \
    "${security_schema_file_path}"

  for dimension_id in "${!security_value_map[@]}"; do
    IFS=' ' read -r -a dimension_values <<<"${security_value_map["${dimension_id}"]}"
    xmlstarlet edit -L \
      --subnode "/tns:SecuritySchema/SecurityPermissions/GroupPermissions[last()]" --type elem -n "Permissions" \
      --insert "/tns:SecuritySchema/SecurityPermissions/GroupPermissions[last()]/Permissions[last()]" --type attr -n "Dimension" --value "${dimension_id}" \
      "${security_schema_file_path}"

    for dimension_value in "${dimension_values[@]}"; do
      xmlstarlet edit -L \
        --subnode "/tns:SecuritySchema/SecurityPermissions/GroupPermissions[last()]/Permissions[last()]" --type elem -n "Permission" \
        --insert "/tns:SecuritySchema/SecurityPermissions/GroupPermissions[last()]/Permissions[last()]/Permission[last()]" --type attr -n "DimensionValue" --value "${dimension_value}" \
        --insert "/tns:SecuritySchema/SecurityPermissions/GroupPermissions[last()]/Permissions[last()]/Permission[last()]" --type attr -n "Level" --value "UPDATE" \
        "${security_schema_file_path}"
    done
  done
}

function add_config_admin_to_command_access_control() {
  local tmp_command_access_control_file_path="/tmp/command-access-control.xml"
  local command_access_control_file_path="${LOCAL_USER_CONFIG_DIR}/command-access-control.xml"
  local command_access_control_container_path="/config/apps/opal-services.war/WEB-INF/classes"

  # Create tmp command-access-control file
  cp "${command_access_control_file_path}" "${tmp_command_access_control_file_path}"

  xmlstarlet edit -L \
    --subnode "/tns:CommandAccessControl" --type elem -n "CommandAccessPermissions" \
    --insert "/tns:CommandAccessControl/CommandAccessPermissions[last()]" --type attr -n "UserGroup" --value "${I2_ANALYZE_ADMIN}" \
    "${tmp_command_access_control_file_path}"

  for permission in "${ADMIN_ACCESS_PERMISSIONS[@]}"; do
    xmlstarlet edit -L \
      --subnode "/tns:CommandAccessControl/CommandAccessPermissions[last()]" --type elem -n "Permission" \
      --insert "/tns:CommandAccessControl/CommandAccessPermissions[last()]/Permission[last()]" --type attr -n "Value" --value "${permission}" \
      "${tmp_command_access_control_file_path}"
  done

  # Copy modified file to container
  docker cp "${tmp_command_access_control_file_path}" "${LIBERTY1_CONTAINER_NAME}:${command_access_control_container_path}"
}

function add_config_admin_to_user_registry() {
  local tmp_user_registry_file_path="/tmp/user.registry.xml"
  local user_registry_file_path="${LOCAL_USER_CONFIG_DIR}/user.registry.xml"
  local user_registry_container_path="/liberty/usr/shared/config"
  local app_admin_password

  # Create tmp user.registry file
  cp "${user_registry_file_path}" "${tmp_user_registry_file_path}"

  app_admin_password=$(get_application_admin_password)
  xmlstarlet edit -L \
    --subnode "/server/basicRegistry" --type elem -n "user" \
    --insert "/server/basicRegistry/user[last()]" --type attr -n "name" --value "${I2_ANALYZE_ADMIN}" \
    --insert "/server/basicRegistry/user[last()]" --type attr -n "password" --value "${app_admin_password}" \
    --subnode "/server/basicRegistry" --type elem -n "group" \
    --insert "/server/basicRegistry/group[last()]" --type attr -n "name" --value "${I2_ANALYZE_ADMIN}" \
    --subnode "/server/basicRegistry/group[@name='${I2_ANALYZE_ADMIN}']" --type elem -n "member" \
    --insert "/server/basicRegistry/group[@name='${I2_ANALYZE_ADMIN}']/member[last()]" --type attr -n "name" --value "${I2_ANALYZE_ADMIN}" \
    "${tmp_user_registry_file_path}"

  # Copy modified registry to container
  docker cp "${tmp_user_registry_file_path}" "${LIBERTY1_CONTAINER_NAME}:${user_registry_container_path}"
}

function add_config_admin_to_server_xml() {
  local tmp_server_xml_file_path="/tmp/server.xml"
  local server_xml_file_path="${LOCAL_USER_CONFIG_DIR}/server.xml"
  local server_xml_container_path="/config"

  # Create tmp server.xml file
  docker cp "${LIBERTY1_CONTAINER_NAME}:${server_xml_container_path}/server.xml" "${tmp_server_xml_file_path}"

  xmlstarlet edit -L \
    --subnode "/server/application/application-bnd/security-role[@name='Administrator']" --type elem -n "group" \
    --insert "/server/application/application-bnd/security-role[@name='Administrator']/group[last()]" --type attr -n "name" --value "${I2_ANALYZE_ADMIN}" \
    "${tmp_server_xml_file_path}"

  # Copy modified server.xml to container
  docker cp "${tmp_server_xml_file_path}" "${LIBERTY1_CONTAINER_NAME}:${server_xml_container_path}"
}

function add_class_to_validation_logger() {
  local class_name="$1"
  local log4j2_file_path="$2"

  xmlstarlet edit -L --subnode "/Configuration/Loggers" --type elem -n "Logger" \
    --insert "/Configuration/Loggers/Logger[last()]" --type attr --name "name" --value "${class_name}" \
    --insert "/Configuration/Loggers/Logger[last()]" --type attr --name "level" --value "WARN" \
    --insert "/Configuration/Loggers/Logger[last()]" --type attr --name "additivity" --value "true" \
    --subnode "/Configuration/Loggers/Logger[last()]" --type elem -n "AppenderRef" \
    --insert "/Configuration/Loggers/Logger[last()]/AppenderRef" --type attr --name "ref" --value "i2_VALIDATIONLOG" \
    "${log4j2_file_path}"
}

function update_log4j_file() {
  local tmp_log4j2_file_path="/tmp/log4j2.xml"
  local log4j2_file_path="${LOCAL_USER_CONFIG_DIR}/log4j2.xml"
  local log4j2_container_path="/config/apps/opal-services.war/WEB-INF/classes"
  local properties_heredoc_file_path="/tmp/properties_heredoc"
  local appenders_heredoc_file_path="/tmp/appenders_heredoc"
  local loggers_heredoc_console_file_path="/tmp/loggers_console_heredoc"
  local loggers_heredoc_availability_file_path="/tmp/loggers_availability_heredoc"
  local loggers_heredoc_mapping_file_path="/tmp/loggers_mapping_heredoc"
  local loggers_heredoc_lifecycle_file_path="/tmp/loggers_lifecycle_heredoc"
  local loggers_heredoc_statehandler_file_path="/tmp/loggers_statehandler_heredoc"
  local loggers_console_name='<Logger name="com.i2group.apollo.common.toolkit.internal.ConsoleLogger"'
  local loggers_console_level="WARN"
  local loggers_console_appender_ref="i2_VALIDATIONLOG"
  local loggers_availability_name='<Logger name="com.i2group.disco.sync.ComponentAvailabilityCheck"'
  local loggers_availability_level="WARN"
  local loggers_availability_appender_ref="i2_VALIDATIONLOG"
  local loggers_mapping_name='<Logger name="com.i2group.opal.daod.mapping.internal"'
  local loggers_mapping_level="WARN"
  local loggers_mapping_appender_ref="i2_VALIDATIONLOG"
  local loggers_lifecycle_name='<Logger name="com.i2group.disco.servlet.ApplicationLifecycleManager"'
  local loggers_lifecycle_level="INFO"
  local loggers_lifecycle_appender_ref="i2_STATUSLOG"
  local loggers_statehandler_name='<Logger name="com.i2group.disco.sync.ApplicationStateHandler"'
  local loggers_statehandler_level="INFO"
  local loggers_statehandler_appender_ref="i2_STATUSLOG"

  print_info "Updating Log4j2.xml file"

  # Create tmp log4j2 file
  cp "${log4j2_file_path}" "${tmp_log4j2_file_path}"

  # Remove any new line breaking xml element
  xmlstarlet edit -L -u '//text()' -x 'normalize-space()' "${tmp_log4j2_file_path}"

  # Creating heredocs
  cat >"${properties_heredoc_file_path}" <<'EOF'
    <Property name="i2_rootDir">${sys:apollo.log.dir}/opal-services</Property>
    <Property name="i2_validationMessagesPatternLayout">%d - %m%n</Property>
    <Property name="i2_archiveDir">${i2_rootDir}/${archiveDirFormat}</Property>
    <Property name="i2_archiveFileDateFormat">%d{dd-MM-yyyy}-%i</Property>
    <Property name="i2_triggerSize">1MB</Property>
    <Property name="i2_maxRollover">10</Property>
  </Properties>
EOF
  cat >"${appenders_heredoc_file_path}" <<'EOF'
    <RollingFile name="i2_VALIDATIONLOG" append="true">
      <FileName>${i2_rootDir}/i2_Validation.log</FileName>
      <FilePattern>"${i2_archiveDir}/i2_Validation-${i2_archiveFileDateFormat}.log</FilePattern>
      <PatternLayout charset="UTF-8" pattern="${i2_validationMessagesPatternLayout}" />
      <Policies>
        <SizeBasedTriggeringPolicy size="${i2_triggerSize}" />
      </Policies>
      <DefaultRolloverStrategy max="${i2_maxRollover}" />
    </RollingFile>
    <RollingFile name="i2_STATUSLOG" append="true">
      <FileName>${i2_rootDir}/i2_Status.log</FileName>
      <FilePattern>"${i2_archiveDir}/i2_Status-${i2_archiveFileDateFormat}.log</FilePattern>
      <PatternLayout charset="UTF-8" pattern="${i2_validationMessagesPatternLayout}" />
      <Policies>
        <SizeBasedTriggeringPolicy size="${i2_triggerSize}" />
      </Policies>
      <DefaultRolloverStrategy max="${i2_maxRollover}" />
    </RollingFile>
  </Appenders>
EOF
  cat >"${loggers_heredoc_console_file_path}" <<'EOF'
    <!-- i2 Analyze Validation Logging -->
    <Logger name="com.i2group.apollo.common.toolkit.internal.ConsoleLogger" level="WARN" additivity="true">
      <AppenderRef ref="i2_VALIDATIONLOG" />
    </Logger>
  </Loggers>
EOF
  cat >"${loggers_heredoc_availability_file_path}" <<'EOF'
    <Logger name="com.i2group.disco.sync.ComponentAvailabilityCheck" level="WARN" additivity="true">
      <AppenderRef ref="i2_VALIDATIONLOG" />
    </Logger>
  </Loggers>
EOF
  cat >"${loggers_heredoc_mapping_file_path}" <<'EOF'
    <Logger name="com.i2group.opal.daod.mapping.internal" level="WARN" additivity="true">
      <AppenderRef ref="i2_VALIDATIONLOG" />
    </Logger>
  </Loggers>
EOF
  cat >"${loggers_heredoc_lifecycle_file_path}" <<'EOF'
    <Logger name="com.i2group.disco.servlet.ApplicationLifecycleManager" level="INFO" additivity="true">
      <AppenderRef ref="i2_STATUSLOG" />
    </Logger>
  </Loggers>
EOF
  cat >"${loggers_heredoc_statehandler_file_path}" <<'EOF'
    <Logger name="com.i2group.disco.sync.ApplicationStateHandler" level="INFO" additivity="true">
      <AppenderRef ref="i2_STATUSLOG" />
    </Logger>
  </Loggers>
EOF

  # Update temporary Log4j2 file with 'i2_' prefixed properties and appenders from heredoc
  replace_xml_element_with_here_doc "<\/Properties>" "${properties_heredoc_file_path}" "${tmp_log4j2_file_path}"
  replace_xml_element_with_here_doc "<\/Appenders>" "${appenders_heredoc_file_path}" "${tmp_log4j2_file_path}"

  # If logger already exists then force set 'level' and append 'AppenderRef', else if
  # logger does not exist then append entire heredoc block for each logger.
  append_logging_xml_element_with_here_doc "${loggers_console_name}" "${loggers_heredoc_console_file_path}" "${loggers_console_level}" "${loggers_console_appender_ref}"
  append_logging_xml_element_with_here_doc "${loggers_availability_name}" "${loggers_heredoc_availability_file_path}" "${loggers_availability_level}" "${loggers_availability_appender_ref}"
  append_logging_xml_element_with_here_doc "${loggers_mapping_name}" "${loggers_heredoc_mapping_file_path}" "${loggers_mapping_level}" "${loggers_mapping_appender_ref}"
  append_logging_xml_element_with_here_doc "${loggers_lifecycle_name}" "${loggers_heredoc_lifecycle_file_path}" "${loggers_lifecycle_level}" "${loggers_lifecycle_appender_ref}"
  append_logging_xml_element_with_here_doc "${loggers_statehandler_name}" "${loggers_heredoc_statehandler_file_path}" "${loggers_statehandler_level}" "${loggers_statehandler_appender_ref}"

  add_class_to_validation_logger "com.i2group.opal.daod.resultsets.search.internal.DaodFacetSummaryConfigurationValidation" "${tmp_log4j2_file_path}"
  add_class_to_validation_logger "com.i2group.disco.security.typeaccess.internal.TypeAccessPermissionsValidator" "${tmp_log4j2_file_path}"

  # Copy modified Logger to container
  docker cp "${tmp_log4j2_file_path}" "${LIBERTY1_CONTAINER_NAME}:${log4j2_container_path}"

  # Remove tmp heredoc files
  rm "${properties_heredoc_file_path}" \
    "${appenders_heredoc_file_path}" \
    "${loggers_heredoc_console_file_path}" \
    "${loggers_heredoc_availability_file_path}" \
    "${loggers_heredoc_mapping_file_path}" \
    "${loggers_heredoc_lifecycle_file_path}" \
    "${loggers_heredoc_statehandler_file_path}"
}

function get_health_live_endpoint_status() {
  local app_admin_password

  app_admin_password=$(get_application_admin_password)
  run_i2_analyze_tool_as_external_user bash -c "curl \
          --silent \
          --cookie-jar /tmp/cookie.txt \
          --cacert /tmp/i2acerts/CA.cer \
          --request POST \"${FRONT_END_URI}/j_security_check\" \
          --header 'Origin: ${FRONT_END_URI}' \
          --header 'Content-Type: application/x-www-form-urlencoded' \
          --data-urlencode 'j_username=${I2_ANALYZE_ADMIN}' \
          --data-urlencode 'j_password=${app_admin_password}' \
        && curl \
          --silent \
          --cookie /tmp/cookie.txt \
          --output /dev/null \
          --cacert /tmp/i2acerts/CA.cer \
          --write-out \"%{http_code}\" \
          \"${FRONT_END_URI}/api/v1/health/live\""
}

function wait_for_liberty_to_be_live() {
  local first_run="${1:-"false"}"
  local exit_on_error="${2:-"true"}"

  print "Waiting for i2 Analyze service to be live"
  local max_tries=15

  if [[ "${first_run}" == "true" ]]; then
    max_tries=30 # Old Mac's are slow. Leave this to be 30 for the first deploy
  fi

  for i in $(seq 1 "${max_tries}"); do
    if get_health_live_endpoint_status &>/dev/null; then
      http_code=$(get_health_live_endpoint_status)
      if [[ "${http_code}" == 200 ]]; then
        echo "i2 Analyze service is live"
        return 0
      fi
    fi

    echo "i2 Analyze service is NOT live (attempt: $i). Waiting..."
    sleep 5
  done

  if [[ "${exit_on_error}" == "true" ]]; then
    docker logs --tail 50 "${LIBERTY1_CONTAINER_NAME}"
    print_error_and_exit "i2 Analyze service is NOT live"
  fi
}

function check_liberty_status() {
  local first_run="${1:-"false"}"
  print "Checking Liberty Status"

  local warn_message="Warnings detected, please review the above message(s)."
  local errors_message="Validation errors detected, please review the above message(s)."
  local validation_log_path="/logs/opal-services/i2_Validation.log"
  local status_log_path="/logs/opal-services/i2_Status.log"
  local validation_messages

  wait_for_liberty_to_be_live "${first_run}" "false"

  # Check or Wait for a known I2ANALYZE_STATUS code:
  #  0002 is success
  #  0005 is exception on startup
  #  0068 is waiting for component availability
  if docker exec -i "${LIBERTY1_CONTAINER_NAME}" bash -c "grep -q '0002\|0005\|0068' <(cat ${status_log_path})" || docker exec -i "${LIBERTY1_CONTAINER_NAME}" bash -c "timeout 3m grep -q '0002\|0005\|0068' <(tail -f ${status_log_path})"; then
    validation_messages=$(docker exec "${LIBERTY1_CONTAINER_NAME}" cat "${validation_log_path}")
    if docker exec -i "${LIBERTY1_CONTAINER_NAME}" bash -c "grep -q '0002' <(cat ${status_log_path})"; then
      if [[ -n "${validation_messages}" ]]; then
        echo "${validation_messages}"
        print_warn "${warn_message}"
      fi
    else
      if [[ -n "${validation_messages}" ]]; then
        echo "${validation_messages}" >&2
        print_error_and_exit "${errors_message}"
      fi
      echo "No Validation errors detected."
    fi
  else
    validation_messages=$(docker exec "${LIBERTY1_CONTAINER_NAME}" cat "${validation_log_path}")
    if [[ -z "${validation_messages}" ]]; then
      docker logs --tail 50 "${LIBERTY1_CONTAINER_NAME}" >&2
    else
      echo "${validation_messages}" >&2
    fi
    print_error_and_exit "Liberty failed to start in time. The last messages logged by the server are above."
  fi
}

#######################################
# Wait for a solr Asynchronous process to be completed.
# Arguments:
#   The Asynchronous ID used to monitor the asynchronous operation.
#######################################
function wait_for_asynchronous_request_status_to_be_completed() {
  local async_id="$1"
  local tries=1
  local max_tries=30

  print "Waiting for ${async_id} to be completed"
  while [[ "${tries}" -le "${max_tries}" ]]; do
    response=$(get_async_request_status "${async_id}")
    if [[ "${response}" == "completed" ]]; then
      echo "${async_id} status has been marked completed" && return 0
    fi

    echo "${async_id} status has not been marked as completed"
    echo "Waiting..."
    sleep 5
    if [[ "${tries}" -ge "${max_tries}" ]]; then
      print_error_and_exit "ERROR: ${async_id} could not be completed: '${response}'"
    fi
    tries=$((tries + 1))
  done
}

#######################################
# Wait for Solr to be live
# Arguments:
#   Solr node to wait for to be live
#######################################
function wait_for_solr_to_be_live() {
  local solr_node="$1"
  local max_tries=30
  local can_access_admin_endpoint="true"

  print "Waiting for Solr Node to be live: ${solr_node}"

  for i in $(seq 1 "${max_tries}"); do
    status_response=$(get_solr_node_status "${solr_node}")
    if [[ "${status_response}" == "ACTIVE" ]]; then
      echo "${solr_node} status: ACTIVE" && return 0
    elif [[ "${status_response}" == "ERROR" ]]; then
      can_access_admin_endpoint="false"
    else
      can_access_admin_endpoint="true"
    fi
    echo "${solr_node} status: ${status_response}"
    sleep 5
    echo "(attempt: ${i}). Waiting..."
  done

  # If you get here, get_solr_node_status has not been successful
  if [[ "${can_access_admin_endpoint}" == "false" ]]; then
    print_error_and_exit "Unable to access ${SOLR1_BASE_URL}/solr/admin/info/health endpoint"
  else
    print_error_and_exit "${solr_node} is NOT live. The list of all live nodes: ${nodes}"
  fi
}

#######################################
# Get Solr node status through Solr API
# Arguments:
#   Solr node to get status of
#######################################
function get_solr_node_status() {
  local solr_node="$1"
  local extra_args=()

  if (run_solr_client_command bash -c "curl --silent -o /dev/null -w \"%{http_code}\" -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" \
  --cacert /tmp/i2acerts/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=CLUSTERSTATUS\"") >/tmp/http_code.txt; then
    http_code=$(cat /tmp/http_code.txt)
    if [[ "${http_code}" -ge 200 && "${http_code}" -lt 300 ]]; then
      (run_solr_client_command bash -c "curl --silent -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" \
  --cacert /tmp/i2acerts/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=CLUSTERSTATUS\"") >/tmp/response.txt
      nodes=$(jq -r '.cluster.live_nodes | join(", ")' /tmp/response.txt)
      if grep -q "${solr_node}" <<<"$nodes"; then
        echo "ACTIVE" && return 0
      fi
    fi
    echo "DOWN - Status code: $http_code"
  else
    echo "ERROR"
  fi
}

#######################################
# Get i2 Analyze Service status.
# Arguments:
#   Liberty instance name. E.g liberty1, liberty2 (defaults to 'all').
# Outputs:
#   i2 Analyze service status: Active, Degraded, Down
#######################################
function get_i2_analyze_service_status() {
  local liberty_instance_name="${1:-all}"
  local load_balancer_stats_status_code
  local load_balancer_stats_response
  local liberty_stats
  local liberty_stats_array
  local liberty_name
  local liberty_status
  local liberty_status_number=17

  load_balancer_stats_status_code="$(
    run_i2_analyze_tool_as_external_user bash -c "curl --write-out \"%{http_code}\" --silent --output /dev/null \
        --cacert /tmp/i2acerts/CA.cer \"${LOAD_BALANCER_STATS_URI}\""
  )"
  # Make sure you get 200 from /haproxy_stats;csv
  if [[ "${load_balancer_stats_status_code}" -eq 200 ]]; then
    # Get Load Balancer Stats
    load_balancer_stats_response="$(
      run_i2_analyze_tool_as_external_user bash -c "curl  --silent --cacert /tmp/i2acerts/CA.cer \"${LOAD_BALANCER_STATS_URI}\""
    )"
    # Make sure response in not empty
    if [[ -n "${load_balancer_stats_response}" ]]; then
      if [[ "${liberty_instance_name}" == "all" ]]; then
        # Determine whether all Liberty servers are Down
        if grep -q "BACKEND" <<<"${load_balancer_stats_response}"; then
          liberty_stats=$(grep "BACKEND" <<<"${load_balancer_stats_response}")
          # Parse line of csv into a $liberty_stats array
          # IFS is a separator used by the 'read' command
          IFS=',' read -r -a liberty_stats_array <<<"${liberty_stats}"
          liberty_status="${liberty_stats_array[${liberty_status_number}]}"
          if [[ "${liberty_status}" != "UP" ]]; then
            echo "DOWN"
            return
          fi
        fi
        # If Liberty Backend is UP, check whether i2 Analyze Service state is Active or Degraded
        while read -r line; do
          if grep -q "liberty" <<<"${line}"; then
            IFS=',' read -r -a liberty_stats_array <<<"${line}"
            liberty_status="${liberty_stats_array[${liberty_status_number}]}"
            if [[ "${liberty_status}" != "UP" ]]; then
              echo "DEGRADED"
              return
            fi
          fi
        done < <(echo "${load_balancer_stats_response}")
      else
        liberty_stats=$(grep "$liberty_instance_name" <<<"${load_balancer_stats_response}")
        IFS=',' read -r -a liberty_stats_array <<<"${liberty_stats}"
        liberty_status="${liberty_stats_array[${liberty_status_number}]}"
        if [[ "${liberty_status}" != "UP" ]]; then
          echo "DOWN"
          return
        fi
      fi
    else
      echo "Empty response from the load balancer stats page (${LOAD_BALANCER_STATS_URI})"
      return
    fi
  else
    echo "Response from the load balancer stats page (${LOAD_BALANCER_STATS_URI}) is not OK. We are getting: ${load_balancer_stats_status_code}"
    return
  fi
  # IF you get here i2 Analyze Service is UP
  echo "ACTIVE"
}

#######################################
# Get ZooKeeper ensemble service status.
# Arguments:
#   None
# Outputs:
#   ZooKeeper ensemble service status: Active, Degraded, Down
#######################################
function get_zk_quorum_ensemble_status() {
  local online_count=0
  local zookeepers=("${ZK1_FQDN}" "${ZK2_FQDN}" "${ZK3_FQDN}")
  local not_serving_error="This ZooKeeper instance is not currently serving requests"

  for zookeeper in "${zookeepers[@]}"; do
    srvr_endpoint="http://${zookeeper}:8080/commands/srvr"
    if [[ $(run_solr_client_command bash -c "curl -s --fail --cacert ${CONTAINER_CERTS_DIR}/CA.cer ${srvr_endpoint}") ]]; then
      response=$(run_solr_client_command bash -c "curl -s --fail --cacert ${CONTAINER_CERTS_DIR}/CA.cer ${srvr_endpoint}")
      error=$(echo "${response}" | jq -r '.error')
      if [[ "${error}" == "null" ]]; then
        online_count=$((online_count + 1))
      elif [[ "${error}" == "${not_serving_error}" ]]; then
        echo "DOWN"
        return
      fi
    fi
  done

  if [[ "${online_count}" == "${#zookeepers[@]}" ]]; then
    echo "ACTIVE"
  else
    echo "DEGRADED"
  fi
}

#######################################
# Wait for the i2 Analyze Service status to be 'Active'.
# Arguments:
#   None
#######################################
function wait_for_i2_analyze_service_to_be_live() {
  local max_tries=30
  local exit_code=1 # Initialize with DOWN
  local i2analyze_service_status

  print "Waiting for i2 Analyze service to be live"

  for i in $(seq 1 "${max_tries}"); do
    i2analyze_service_status="$(get_i2_analyze_service_status)"
    if [[ "${i2analyze_service_status}" == "ACTIVE" ]]; then
      exit_code=0
      break
    elif [[ "${i2analyze_service_status}" == "DOWN" ]]; then
      echo "i2 Analyze service state: 'DOWN' (attempt: ${i}). Waiting..."
      exit_code=1
    elif [[ "${i2analyze_service_status}" == "DEGRADED" ]]; then
      echo "i2 Analyze service state: 'DEGRADED' (attempt: ${i}). Waiting..."
      exit_code=2
    else
      echo "${i2analyze_service_status}"
    fi
    sleep 5
  done

  if [[ "${exit_code}" -eq 0 ]]; then
    echo "i2 Analyze service state: 'ACTIVE'"
  elif [[ "${exit_code}" -eq 1 ]]; then
    print_error_and_exit "i2 Analyze service state: 'DOWN'"
  elif [[ "${exit_code}" -eq 2 ]]; then
    print_error_and_exit "i2 Analyze service state: 'DEGRADED'"
  else
    print_error_and_exit "ERROR: ${i2analyze_service_status}"
  fi
}

#######################################
# Wait for SQL Server to be live. The functions performs
# a simple non consequential query to check whether SQL Server is live.
# Arguments:
#   1 - first_run: {true, false}
#       if 'true' uses the initial SA Password
#       if 'false' uses SA Password
#######################################
function wait_for_sql_server_to_be_live() {
  local max_tries=30
  local sql_query='SELECT 1'
  local first_run="${1:-false}"
  print "Waiting for SQL Server to be live"
  for i in $(seq 1 "${max_tries}"); do
    if [[ "${first_run}" == "true" ]]; then
      if run_sql_server_command_as_first_start_sa run-sql-query "${sql_query}"; then
        echo "SQL Server is live" && return 0
      fi
    else
      if run_sql_server_command_as_sa run-sql-query "${sql_query}"; then
        echo "SQL Server is live" && return 0
      fi
    fi
    echo "SQL Server is NOT live (attempt: ${i}). Waiting..."
    sleep 5
  done

  # If you get here, wait_for_sql_server_to_be_live has not been successful
  print_error_and_exit "SQL Server is NOT live."
}

#######################################
# Wait for Postgres Server to be live. The functions performs
# a simple non consequential query to check whether Postgres Server is live.
# Arguments:
#   1 - first_run: {true, false}
#       if 'true' uses the initial postgres password
#       if 'false' uses postgres password
#######################################
function wait_for_postgres_server_to_be_live() {
  local max_tries=30
  local sql_query='SELECT 1'
  local first_run="${1:-false}"
  print "Waiting for Postgres Server to be live"
  for i in $(seq 1 "${max_tries}"); do
    if [[ "${first_run}" == "true" ]]; then
      if run_postgres_server_command_as_first_start_postgres run-sql-query "${sql_query}"; then
        echo "Postgres Server is live" && return 0
      fi
    else
      if run_postgres_server_command_as_postgres run-sql-query "${sql_query}"; then
        echo "Postgres Server is live" && return 0
      fi
    fi
    echo "Postgres Server is NOT live (attempt: ${i}). Waiting..."
    sleep 5
  done

  # If you get here, wait_for_postgres_server_to_be_live has not been successful
  print_error_and_exit "Postgres Server is NOT live."
}

#######################################
# Wait for Db2 Server to be live. The functions performs
# a simple non consequential query to check whether Db2 Server is live.
# Arguments:
#   1 - first_run: {true, false}
#       if 'true' uses the initial db2inst1 Password
#       if 'false' uses db2inst1 Password
#######################################
function wait_for_db2_server_to_be_live() {
  local max_tries=30
  local sql_query='TERMINATE'
  local first_run="${1:-false}"
  print "Waiting for Db2 Server to be live"
  for i in $(seq 1 "${max_tries}"); do
    if [[ "${first_run}" == "true" ]]; then
      if run_db2_server_command_as_first_start_db2inst1 run-sql-query "${sql_query}"; then
        echo "Db2 Server is live" && return 0
      fi
    else
      if run_db2_server_command_as_db2inst1 run-sql-query "${sql_query}"; then
        echo "Db2 Server is live" && return 0
      fi
    fi
    echo "Db2 Server is NOT live (attempt: ${i}). Waiting..."
    sleep 5
  done

  # If you get here, wait_for_db2_server_to_be_live has not been successful
  print_error_and_exit "Db2 Server is NOT live."
}

#######################################
# Wait for Prometheus to be live
#######################################
function wait_for_prometheus_server_to_be_live() {
  local max_tries=30
  local prometheus_password
  prometheus_password=$(get_prometheus_admin_password)
  local prometheus_target_health
  local liberty1_target_health liberty2_target_health
  local analyze1_target_health analyze2_target_health

  print "Waiting for Prometheus to be live"
  for i in $(seq 1 "${max_tries}"); do
    if status_code=$(run_i2_analyze_tool_as_external_user bash -c \
      "curl --write-out \"%{http_code}\" \
      --silent \
      --output /dev/null \
      -u ${PROMETHEUS_USERNAME}:${prometheus_password} \
      --cacert /tmp/i2acerts/CA.cer \
      https://${PROMETHEUS_FQDN}:9090/-/healthy"); then
      if [[ "${status_code}" == 200 ]]; then
        echo "Prometheus is live" && return 0
      fi
    fi
    echo "Prometheus is NOT live (attempt: ${i}). Waiting..."
    sleep 5
  done
  docker logs --tail 50 "${PROMETHEUS_CONTAINER_NAME}"
  print_error_and_exit "Prometheus is NOT live"
}

#######################################
# Wait for Grafana to be live
#######################################
function wait_for_grafana_server_to_be_live() {
  local max_tries=30
  local grafana_password
  grafana_password=$(get_secret "grafana/admin_PASSWORD")

  print "Waiting for Grafana to be live"
  for i in $(seq 1 "${max_tries}"); do
    if status_code=$(run_i2_analyze_tool_as_external_user bash -c \
      "curl --write-out \"%{http_code}\" \
      --silent \
      --output /dev/null \
      -u ${GRAFANA_USERNAME}:${grafana_password} \
      --cacert /tmp/i2acerts/CA.cer \
      https://${GRAFANA_FQDN}:3000/api/health"); then
      if [[ "${status_code}" == 200 ]]; then
        print_info "Checking Grafana Datasource"
        status_code=$(run_i2_analyze_tool_as_external_user bash -c \
          "curl --write-out \"%{http_code}\" \
          --silent \
          --output /dev/null \
          -X POST \"https://${GRAFANA_FQDN}:3000/api/ds/query\" \
          -H \"content-type: application/json\" \
          --cacert /tmp/i2acerts/CA.cer \
          -u ${GRAFANA_USERNAME}:${grafana_password} \
          --data-raw '{\"queries\":[{\"refId\":\"test\",\"expr\":\"1+1\",\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"}}],\"from\":\"now-1m\",\"to\":\"now\"}'")
        if [[ "${status_code}" == 200 ]]; then
          echo "Grafana is live" && return 0
        fi
      fi
    fi
    echo "Grafana is NOT live (attempt: ${i}). Waiting..."
    sleep 5
  done
  docker logs --tail 50 "${GRAFANA_CONTAINER_NAME}"
  print_error_and_exit "Grafana is NOT live"
}

#######################################
# Runs i2 Analyze request as a gateway user
# Arguments:
#   None
#######################################
function run_i2_analyze_tool_as_gateway_user() {
  local SSL_OUTBOUND_PRIVATE_KEY
  local SSL_OUTBOUND_CERTIFICATE
  local SSL_CA_CERTIFICATE
  SSL_OUTBOUND_PRIVATE_KEY=$(get_secret certificates/gateway_user/server.key)
  SSL_OUTBOUND_CERTIFICATE=$(get_secret certificates/gateway_user/server.cer)
  SSL_CA_CERTIFICATE=$(get_secret certificates/CA/CA.cer)

  docker run --rm \
    --network "${DOMAIN_NAME}" \
    -e GATEWAY_SSL_CONNECTION="${GATEWAY_SSL_CONNECTION}" \
    -e SSL_OUTBOUND_PRIVATE_KEY="${SSL_OUTBOUND_PRIVATE_KEY}" \
    -e SSL_OUTBOUND_CERTIFICATE="${SSL_OUTBOUND_CERTIFICATE}" \
    -e SSL_CA_CERTIFICATE="${SSL_CA_CERTIFICATE}" \
    "${I2A_TOOLS_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "$@"
}

#######################################
# Puts a key and value pair in a bash 3 compatible map.
# Arguments:
#   1: The map name
#   2: The key
#   3: The value
#######################################
function map_put() {
  alias "${1}${2}=${3}"
}

#######################################
# Gets a value pair from a bash 3 compatible map.
# Arguments:
#   1: The map name
#   2: The key
# Returns:
#   The value from the specified map
#######################################
function map_get() {
  alias "${1}${2}" | awk -F"'" '{ print $2; }'
}

#######################################
# Gets all the keys from a bash 3 compatible map.
# Arguments:
#   1: The map name
# Returns:
#   The keys from the specified map
#######################################
function map_keys() {
  alias -p | grep "$1" | cut -d'=' -f1 | awk -F"$1" '{print $2; }'
}

#######################################
# Prints a heading style message to the console.
# Arguments:
#   1: The message
#######################################
function print() {
  echo ""
  echo "#----------------------------------------------------------------------"
  echo "# $1"
  echo "#----------------------------------------------------------------------"
}

#######################################
# Prints an error and exists.
# Arguments:
#   1: The message
#######################################
function print_error() {
  printf "\n\e[31mERROR: %s\n" "$1" >&2
  printf "\e[0m" >&2
}

#######################################
# Prints an error message to the console,
# then exit 1.
# Arguments:
#   1: The message
#######################################
function print_error_and_exit() {
  printf "\n\e[31mERROR: %s\n" "$1" >&2
  printf "\e[0m" >&2
  if [[ "${CONTINUE_ON_ERROR}" == "true" ]]; then
    EXECUTED_WITH_ERRORS="true"
    return
  fi
  exit 1
}

#######################################
# Prints a success message to the console if no errors.
# Arguments:
#   1: The message
#######################################
function print_success() {
  if [[ "${EXECUTED_WITH_ERRORS}" != "true" ]]; then
    printf "\n\e[32mSUCCESS: %s\n" "$1" >&2
    printf "\e[0m" >&2
  fi
}

#######################################
# Prints an error message to the console,
# then prints usage and error.
# Arguments:
#   1: The message
#######################################
function print_error_and_usage() {
  local error_message="$1"

  print_error "${error_message}"
  print_usage 1
}

#######################################
# Prints an error message to the console
# Arguments:
#   1: The message
#######################################
function print_warn() {
  printf "\n\e[33mWARN: %s\n" "$1"
  printf "\e[0m"
}

#######################################
# Prints an INFO message to the console.
# Arguments:
#   1: The message
#######################################
function print_info() {
  if [[ "${VERBOSE}" == "true" ]]; then
    printf "[INFO] %s\n" "$1"
  fi
}

#######################################
# Delete file if exists.
# Arguments:
#   1: File path
#######################################
function delete_file_if_exists() {
  local file_path="$1"
  if [[ -f "${file_path}" ]]; then
    rm -f "${file_path}"
  fi
}

#######################################
# Removes Folder if it exists.
# Arguments:
#   1: Folder path
#######################################
function delete_folder_if_exists() {
  local folder_path="$1"
  if [[ -d "${folder_path}" ]]; then
    rm -rf "${folder_path}"
  fi
}

#######################################
# Removes Folder if it exists and create a new one.
# Arguments:
#   1: Folder path
#######################################
function delete_folder_if_exists_and_create() {
  local folder_path="$1"

  print_info "Deleting folder: ${folder_path}"
  delete_folder_if_exists "${folder_path}"

  print_info "Creating folder: ${folder_path}"
  create_folder "${folder_path}"
}

#######################################
# Create folder if it doesn't exist.
# Arguments:
#   1: Folder path
#######################################
function create_folder() {
  local folder_path="$1"

  if [[ ! -d "${folder_path}" ]]; then
    mkdir -p "${folder_path}"
  fi
}

#######################################
# Print error if command not installed.
# Arguments:
#   1: Command
#######################################
function print_error_if_command_not_installed() {
  local command="$1"
  if ! command -v "${command}" &>/dev/null; then
    print_error_and_exit "${command} could not be found."
  fi
}

#######################################
# Create dsid.properties file
# Arguments:
#   1: File path for the properties file
#######################################
function create_dsid_properties_file() {
  local dsid_properties_file_path="$1"
  local dsid_file_name
  local dsid_folder_path
  dsid_folder_path="$(dirname "${dsid_properties_file_path}")"
  dsid_file_name="$(basename "${dsid_properties_file_path}")"

  if [[ ! -f "${dsid_properties_file_path}" ]]; then
    print "Creating ${dsid_file_name} file"
    create_folder "${dsid_folder_path}"
    print_error_if_command_not_installed uuidgen
    echo "DataSourceId=$(uuidgen)" >"${dsid_properties_file_path}"
  fi
}

#######################################
# Stop docker container
# Arguments:
#   1: container name or id
#######################################
function stop_container() {
  local container_name_or_id="$1"
  local max_retries=10
  while ! docker stop "${container_name_or_id}"; do
    if ((max_retries == 0)); then
      print_error_and_exit "Unable to stop container '${container_name_or_id}', exiting script"
    else
      echo "[WARN] Having issues stopping container '${container_name_or_id}', retrying..."
      max_retries=$((max_retries - 1))
    fi
    sleep 1s
  done
}

#######################################
# Remove docker container
# Arguments:
#   1: container name or id
#######################################
function remove_container() {
  local container_name_or_id="$1"
  local max_retries=10
  while ! docker rm "${container_name_or_id}"; do
    if ((max_retries == 0)); then
      print_error_and_exit "Unable to remove container '${container_name_or_id}', exiting script"
    else
      echo "[WARN] Having issues removing container '${container_name_or_id}', retrying..."
      max_retries=$((max_retries - 1))
    fi
    sleep 1s
  done
}

#######################################
# Removes containers based on the CONFIG_NAME.
# Arguments:
#   None
#######################################
function remove_all_containers_for_the_config() {
  local config_name="$1"
  if [[ -z $(docker network ls -q --filter name="^${DOMAIN_NAME}$") ]]; then
    return
  fi
  print "Removing containers running in the network (${DOMAIN_NAME}) with the config name (${config_name}) and version (${SUPPORTED_I2ANALYZE_VERSION})"

  local container_ids
  IFS=' ' read -ra container_ids <<<"$(docker ps -aq -f network="${DOMAIN_NAME}" -f name="\.${config_name}_${CONTAINER_VERSION_SUFFIX}$" | xargs)"
  for container_id in "${container_ids[@]}"; do
    delete_container "${container_id}"
  done
}

function clean_up_docker_resources() {
  delete_all_pre_prod_containers
  stop_config_dev_containers
  stop_connector_containers
  if [[ "${ENVIRONMENT}" == "pre-prod" ]]; then
    remove_docker_volumes
  fi
}

function delete_all_pre_prod_containers() {
  local pre_prod_containers=(
    "${ZK1_CONTAINER_NAME%%.*}"
    "${ZK2_CONTAINER_NAME%%.*}"
    "${ZK3_CONTAINER_NAME%%.*}"
    "${SOLR1_CONTAINER_NAME%%.*}"
    "${SOLR2_CONTAINER_NAME%%.*}"
    "${SOLR3_CONTAINER_NAME%%.*}"
    "${SQL_SERVER_CONTAINER_NAME%%.*}"
    "${LIBERTY1_CONTAINER_NAME%%.*}"
    "${LIBERTY2_CONTAINER_NAME%%.*}"
    "${LOAD_BALANCER_CONTAINER_NAME%%.*}"
    "${CONNECTOR1_CONTAINER_NAME%%.*}"
    "${CONNECTOR2_CONTAINER_NAME%%.*}"
    "${PROMETHEUS_CONTAINER_NAME%%.*}"
    "${GRAFANA_CONTAINER_NAME%%.*}"
  )

  for pre_prod_container in "${pre_prod_containers[@]}"; do
    force_delete_container "${pre_prod_container}"
  done
}

function delete_all_containers() {
  local container_names container_name prefix

  CONTAINER_NAMES_PREFIX=("etlclient" "i2atool" "zk" "solr" "sql" "db2" "liberty" "load_balancer" "exampleconnector" "prometheus" "grafana" "postgres")

  print "Removing all containers"

  IFS=' ' read -ra container_names <<<"$(docker ps --format "{{.Names}}" -f network="${DOMAIN_NAME}" | xargs)"
  for container_name in "${container_names[@]}"; do
    for prefix in "${CONTAINER_NAMES_PREFIX[@]}"; do
      if [[ "${container_name}" == "${prefix}"* ]]; then
        force_delete_container "${container_name}"
      fi
    done
  done
}

function stop_config_dev_containers() {
  local container_names container_name prefix

  CONTAINER_NAMES_PREFIX=("etlclient" "i2atool" "zk" "solr" "sql" "db2" "liberty" "load_balancer" "exampleconnector" "prometheus" "grafana" "postgres")

  print "Stopping containers for other configs"

  IFS=' ' read -ra container_names <<<"$(docker ps --format "{{.Names}}" -f network="${DOMAIN_NAME}" | xargs)"
  for container_name in "${container_names[@]}"; do
    for prefix in "${CONTAINER_NAMES_PREFIX[@]}"; do
      if [[ "${container_name}" == "${prefix}"* ]]; then
        if [[ "${ENVIRONMENT}" == "config-dev" && "${container_name}" == *".${CONFIG_NAME}_${CONTAINER_VERSION_SUFFIX}" ]]; then
          if [[ ("${prefix}" == "db2" && "${DB_DIALECT}" != "db2") ||
            ("${prefix}" == "sql" && "${DB_DIALECT}" != "sqlserver") ||
            ("${prefix}" == "postgres" && "${DB_DIALECT}" != "postgres") ]]; then
            stop_container "${container_name}"
          else
            # Skip current config containers
            continue
          fi
        fi
        stop_container "${container_name}"
      fi
    done
  done
}

function stop_connector_containers() {
  local container_names container_name config_connector_names
  local connector_references_file="${LOCAL_USER_CONFIG_DIR}/connector-references.json"

  # Get all connector running
  IFS=' ' read -ra container_names <<<"$(docker ps --format "{{.Names}}" -f name="^${CONNECTOR_PREFIX}" | xargs)"

  if [[ -n "${CONFIG_NAME}" ]]; then
    readarray -t config_connector_names < <(jq -r '.connectors // empty | .[].name' <"${connector_references_file}")
  fi
  print "Stopping connector containers for other configs"
  for container_name in "${container_names[@]}"; do
    # shellcheck disable=SC2076
    if [[ -n "${CONFIG_NAME}" && " ${config_connector_names[*]} " =~ " ${container_name//${CONNECTOR_PREFIX}/} " ]]; then
      # Skip current config containers
      continue
    fi
    stop_container "${container_name}"
  done
}

function restart_docker_containers_for_config() {
  local config_name="$1"
  local database_restarted="false"
  local solr_restarted="false"
  local all_exited_container_names

  IFS=' ' read -ra all_exited_container_names <<<"$(docker ps -a --format "{{.Names}}" -f name="\.${config_name}_${CONTAINER_VERSION_SUFFIX}$" -f status=exited | xargs)"

  if [[ "${#all_exited_container_names[@]}" -gt 0 ]]; then
    print "Restarting containers for config: ${config_name}"
    # Restarting containers
    for container_name in "${all_exited_container_names[@]}"; do
      # if previously deployed without the istore don't start it up, should be handled later in the code if needed
      if [[ "${container_name}" == "${SQL_SERVER_CONTAINER_NAME}" || "${container_name}" == "${DB2_SERVER_CONTAINER_NAME}" || "${container_name}" == "${POSTGRES_SERVER_CONTAINER_NAME}" ]] && [[ "${PREVIOUS_DEPLOYMENT_PATTERN}" != *"store"* ]]; then
        continue
      fi
      if [[ ("${container_name}" == "${SQL_SERVER_CONTAINER_NAME}" && "${DB_DIALECT}" != "sqlserver") || ("${container_name}" == "${DB2_SERVER_CONTAINER_NAME}" && "${DB_DIALECT}" != "db2") || ("${container_name}" == "${POSTGRES_SERVER_CONTAINER_NAME}" && "${DB_DIALECT}" != "postgres") ]]; then
        continue
      fi
      docker start "${container_name}"
      if [[ "${container_name}" == "${SQL_SERVER_CONTAINER_NAME}" || "${container_name}" == "${DB2_SERVER_CONTAINER_NAME}" || "${container_name}" == "${POSTGRES_SERVER_CONTAINER_NAME}" ]]; then
        database_restarted="true"
      elif [[ "${container_name}" == "${SOLR1_CONTAINER_NAME}" ]] || [[ "${container_name}" == "${ZK1_CONTAINER_NAME}" ]]; then
        solr_restarted="true"
      fi
    done

    # Waiting for system to be up if state is pass the creation
    if source "${PREVIOUS_STATE_FILE_PATH}"; then
      if [[ "${database_restarted}" == "true" && "${STATE}" -gt 2 ]]; then
        wait_for_db_to_be_live
      elif [[ "${solr_restarted}" == "true" && "${STATE}" -gt 2 ]]; then
        wait_for_solr_to_be_live "${SOLR1_FQDN}"
      fi
    fi
  fi
}

#######################################
# Prompt user to reply y/n to a question
# Arguments:
#   The question
#######################################
function wait_for_user_reply() {
  local question="$1"
  echo "" # print an empty line

  if [[ "${YES_FLAG}" == "true" ]]; then
    echo "${question} (y/n) "
    echo "You selected -y flag, continuing"
    return 0
  fi

  while true; do
    read -r -p "${question} (y/n) " yn
    case $yn in
    [Yy]*) echo "" && break ;;
    [Nn]*) exit 1 ;;
    *) ;;
    esac
  done
}

#######################################
# Checks if a volume exists before attempting to remove it.
# This avoids unnecessary console output when a volume does
# not exist.
# Arguments:
#   The name  of the Docker volume to delete
#######################################
function quietly_remove_docker_volume() {
  local volume_to_delete="$1"

  if grep -q ^"$volume_to_delete"$ <<<"$(docker volume ls -q)"; then
    docker volume rm "$volume_to_delete"
  fi
}

#######################################
# Runs a Solr container as root to change permissions on the Solr backup volume.
# Arguments:
#   None
#######################################
function run_solr_container_with_backup_volume() {
  docker run --rm \
    -v "${SOLR_BACKUP_VOLUME_NAME}:${SOLR_BACKUP_VOLUME_LOCATION}" \
    --user="root" \
    "${SOLR_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "$@"
}

#######################################
# Runs a DB container as root to change permissions on the DB backup volume.
# Arguments:
#   None
#######################################
function run_db_container_with_backup_volume() {
  case "${DB_DIALECT}" in
  sqlserver)
    image_name="${SQL_SERVER_IMAGE_NAME}"
    image_tag="${I2A_DEPENDENCIES_IMAGES_TAG}"
    volume_name="${SQL_SERVER_BACKUP_VOLUME_NAME}"
    ;;
  db2)
    image_name="${DB2_SERVER_IMAGE_NAME}"
    image_tag="${I2A_DEPENDENCIES_IMAGES_TAG}"
    volume_name="${DB2_SERVER_BACKUP_VOLUME_NAME}"
    ;;
  postgres)
    image_name="${POSTGRES_SERVER_IMAGE_NAME}"
    image_tag="${POSTGRES_IMAGE_VERSION}"
    volume_name="${POSTGRES_SERVER_BACKUP_VOLUME_NAME}"
    ;;
  esac

  docker run --rm \
    -v "${volume_name}:${DB_CONTAINER_BACKUP_DIR}" \
    --user="root" \
    "${image_name}:${image_tag}" "$@"
}

function backup_database() {
  local backup_file_path="${DB_CONTAINER_BACKUP_DIR}/${BACKUP_NAME}/${DB_BACKUP_FILE_NAME}"
  case "${DB_DIALECT}" in
  db2)
    print_error_and_exit "Not implemented yet"
    ;;
  sqlserver)
    print "Backing up the ${DB_NAME} database for container: ${SQL_SERVER_CONTAINER_NAME}"
    if [[ "${VERSION}" < "2.4.0" ]]; then
      updateVolume "${BACKUP_DIR}" "${SQL_SERVER_BACKUP_VOLUME_NAME}" "${DB_CONTAINER_BACKUP_DIR}"
    else
      update_volume "${BACKUP_DIR}" "${SQL_SERVER_BACKUP_VOLUME_NAME}" "${DB_CONTAINER_BACKUP_DIR}"
      echo "Debug: Updating permission"
    fi
    if [[ "${VERSION}" < "2.3.0" ]]; then
      run_db_container_with_backup_volume chown -R root "${DB_CONTAINER_BACKUP_DIR}/${BACKUP_NAME}"
    else
      run_db_container_with_backup_volume chown -R mssql:0 "${DB_CONTAINER_BACKUP_DIR}/${BACKUP_NAME}"
    fi

    local sql_query="\
      USE ${DB_NAME};
        BACKUP DATABASE ${DB_NAME}
        TO DISK = '${backup_file_path}'
        WITH FORMAT;"

    # TODO: Remove on major version
    if [[ "${VERSION}" < "2.4.0" ]]; then
      runSQLServerCommandAsDBB runSQLQuery "${sql_query}"
      getVolume "${BACKUP_DIR}" "${SQL_SERVER_BACKUP_VOLUME_NAME}" "${DB_CONTAINER_BACKUP_DIR}"
    else
      run_sql_server_command_as_dbb run-sql-query "${sql_query}"
      get_volume "${BACKUP_DIR}" "${SQL_SERVER_BACKUP_VOLUME_NAME}" "${DB_CONTAINER_BACKUP_DIR}"
    fi
    ;;
  postgres)
    print "Backing up the ${DB_NAME} database for container: ${POSTGRES_SERVER_CONTAINER_NAME}"
    update_volume "${BACKUP_DIR}" "${POSTGRES_SERVER_BACKUP_VOLUME_NAME}" "${DB_CONTAINER_BACKUP_DIR}"
    run_db_container_with_backup_volume chown -R postgres:0 "${DB_CONTAINER_BACKUP_DIR}/${BACKUP_NAME}"
    docker exec "${POSTGRES_SERVER_CONTAINER_NAME}" bash -c "/usr/bin/pg_dump ${DB_NAME} > ${backup_file_path}"
    get_volume "${BACKUP_DIR}" "${POSTGRES_SERVER_BACKUP_VOLUME_NAME}" "${DB_CONTAINER_BACKUP_DIR}"
    ;;
  esac
}

#######################################
# Removes all the i2 Analyze related docker volumes.
# Arguments:
#   None
#######################################
function remove_docker_volumes() {
  print "Removing all associated volumes"
  quietly_remove_docker_volume "${SQL_SERVER_VOLUME_NAME}"
  quietly_remove_docker_volume "${SQL_SERVER_BACKUP_VOLUME_NAME}"
  quietly_remove_docker_volume "${POSTGRES_SERVER_VOLUME_NAME}"
  quietly_remove_docker_volume "${POSTGRES_SERVER_BACKUP_VOLUME_NAME}"
  quietly_remove_docker_volume "${DB2_SERVER_VOLUME_NAME}"
  quietly_remove_docker_volume "${DB2_SERVER_BACKUP_VOLUME_NAME}"
  quietly_remove_docker_volume "${SOLR1_VOLUME_NAME}"
  quietly_remove_docker_volume "${SOLR2_VOLUME_NAME}"
  quietly_remove_docker_volume "${SOLR3_VOLUME_NAME}"
  quietly_remove_docker_volume "${ZK1_DATA_VOLUME_NAME}"
  quietly_remove_docker_volume "${ZK2_DATA_VOLUME_NAME}"
  quietly_remove_docker_volume "${ZK3_DATA_VOLUME_NAME}"
  quietly_remove_docker_volume "${ZK1_DATALOG_VOLUME_NAME}"
  quietly_remove_docker_volume "${ZK2_DATALOG_VOLUME_NAME}"
  quietly_remove_docker_volume "${ZK3_DATALOG_VOLUME_NAME}"
  quietly_remove_docker_volume "${ZK1_LOG_VOLUME_NAME}"
  quietly_remove_docker_volume "${ZK2_LOG_VOLUME_NAME}"
  quietly_remove_docker_volume "${ZK3_LOG_VOLUME_NAME}"
  quietly_remove_docker_volume "${LIBERTY1_VOLUME_NAME}"
  quietly_remove_docker_volume "${LIBERTY2_VOLUME_NAME}"
  quietly_remove_docker_volume "${SOLR_BACKUP_VOLUME_NAME}"
  quietly_remove_docker_volume "${PROMETHEUS_DATA_VOLUME_NAME}"
  quietly_remove_docker_volume "${PROMETHEUS_CONFIG_VOLUME_NAME}"
  quietly_remove_docker_volume "${GRAFANA_DATA_VOLUME_NAME}"
  quietly_remove_docker_volume "${GRAFANA_PROVISIONING_VOLUME_NAME}"
  quietly_remove_docker_volume "${GRAFANA_DASHBOARDS_VOLUME_NAME}"
}

#######################################
# Creates docker network if it doesn't exist.
# Arguments:
#   None
#######################################
function create_docker_network() {
  local name=$1
  if [[ -z $(docker network ls -q --filter name="^${name}$") ]]; then
    print "Creating docker network: ${name}"
    docker network create "${name}"
  fi
}

#######################################
# Prints out the current timestamp,
# in the format that can be passed to the `docker logs`
# with `--since` flag
# Arguments:
#   None
#######################################
function get_time_stamp() {
  date --rfc-3339=seconds | sed 's/ /T/'
}

#######################################
# Check variables is set and prints an error if not.
# Arguments:
#   1. Variable value
#   2. Error message to be printed in case of a failure
#######################################
function check_variable_is_set() {
  local var_value="$1"
  local error_message="$2"
  if [[ -z "${var_value}" ]]; then
    print_error_and_exit "${error_message}"
  fi
}

#######################################
# Checks ENVIRONMENT is a valid environment name.
# Arguments:
#   None
#######################################
function check_environment_is_valid() {
  check_variable_is_set "${ENVIRONMENT}" "ENVIRONMENT environment variable is not set"
  if [ "${ENVIRONMENT}" != "pre-prod" ] && [ "${ENVIRONMENT}" != "config-dev" ] && [ "${ENVIRONMENT}" != "aws" ]; then
    print_error_and_exit "${ENVIRONMENT} is not a valid environment name"
  fi
}

#######################################
# Checks if docker daemon is running.
# Arguments:
#   None
#######################################
function check_docker_is_running() {
  if ! docker ps >/dev/null 2>&1; then
    print_error "Docker error"
    docker ps
  fi
}

#######################################
# Returns the application admin password depending
# of the environment.
# Arguments:
#   None
#######################################
function get_application_admin_password() {
  local app_admin_password

  if [[ "${ENVIRONMENT}" == "pre-prod" ]]; then
    app_admin_password="${I2_ANALYZE_ADMIN}"
  else
    app_admin_password=$(get_secret application/admin_PASSWORD)
  fi

  echo "${app_admin_password}"
}

#######################################
# Returns the prometheus admin password depending
# of the environment.
# Arguments:
#   None
#######################################
function get_prometheus_admin_password() {
  local prometheus_admin_password

  if [[ "${ENVIRONMENT}" == "pre-prod" ]]; then
    prometheus_admin_password="${PROMETHEUS_USERNAME}"
  else
    prometheus_admin_password=$(get_secret prometheus/admin_PASSWORD)
  fi

  echo "${prometheus_admin_password}"
}

#######################################
# Checks DEPLOYMENT_PATTERN is valid.
# Arguments:
#   None
#######################################
function check_deployment_pattern_is_valid() {
  check_variable_is_set "${DEPLOYMENT_PATTERN}" "DEPLOYMENT_PATTERN environment variable is not set"
  if [ "${DEPLOYMENT_PATTERN}" != "schema_dev" ] && [ "${DEPLOYMENT_PATTERN}" != "istore" ] && [ "${DEPLOYMENT_PATTERN}" != "cstore" ] &&
    [ "${DEPLOYMENT_PATTERN}" != "i2c" ] && [ "${DEPLOYMENT_PATTERN}" != "i2c_istore" ] && [ "${DEPLOYMENT_PATTERN}" != "i2c_cstore" ]; then
    print_error_and_exit "${DEPLOYMENT_PATTERN} is not not a valid deployment pattern"
  fi
}

#######################################
# Checks if DEPLOYMENT_PATTERN contains i2connect.
# Arguments:
#   None
#######################################
function is_i2_connect_deployment_pattern() {
  if [[ $DEPLOYMENT_PATTERN == *"i2c"* ]]; then
    return 0
  else
    return 1
  fi
}

function check_db_container_exist() {
  local container
  if [[ "${PREVIOUS_DEPLOYMENT_PATTERN}" == *"store"* ]]; then
    case "${PREVIOUS_DB_DIALECT}" in
    db2)
      container="${DB2_SERVER_CONTAINER_NAME}"
      ;;
    sqlserver)
      container="${SQL_SERVER_CONTAINER_NAME}"
      ;;
    postgres)
      container="${POSTGRES_SERVER_CONTAINER_NAME}"
      ;;
    *)
      print_error_and_exit "Unknown dialect"
      ;;
    esac
    if [[ -z "$(docker ps -aq -f name="^${container}$")" ]]; then
      echo "${container} does NOT exist"
      return 1
    fi
  fi
  return 0
}

#######################################
# Checks required containers for the current deploy exist.
# Arguments:
#   None
# Returns:
#   0 - if all exist
#   1 - if >=1 does NOT exist
#######################################
function check_containers_exist() {
  local all_present=0
  local containers=("${SOLR1_CONTAINER_NAME}" "${ZK1_CONTAINER_NAME}" "${LIBERTY1_CONTAINER_NAME}" "${PROMETHEUS_CONTAINER_NAME}" "${GRAFANA_CONTAINER_NAME}")

  print "Checking all containers required for the deployment exist"

  for container in "${containers[@]}"; do
    if [[ -z "$(docker ps -aq -f name="^${container}$")" ]]; then
      echo "${container} does NOT exist"
      all_present=1
    fi
  done

  return "${all_present}"
}

#######################################
# Checks required connector containers for the current deploy exist.
# Arguments:
#   None
# Returns:
#   0 - if all exist
#   1 - if >=1 does NOT exist
#######################################
function check_connector_containers_exist() {
  if [ "${DEPLOYMENT_PATTERN}" != "istore" ] && [ "${DEPLOYMENT_PATTERN}" != "cstore" ]; then
    local all_present=0
    local connector_references_file="${PREVIOUS_CONFIGURATION_DIR}/configuration/connector-references.json"
    local connector_name connector_type
    local all_connector_names
    IFS=' ' read -ra all_connector_names <<<"$(jq -r '.connectors // empty | .[].name' <"${connector_references_file}" | xargs)"
    for connector_name in "${all_connector_names[@]}"; do
      connector_type=$(jq -r '.type' <"${CONNECTOR_IMAGES_DIR}/${connector_name}/connector-definition.json")
      if [[ "${connector_type}" != "${EXTERNAL_CONNECTOR_TYPE}" && -z "$(docker ps -aq -f name="^${CONNECTOR_PREFIX}${connector_name}$")" ]]; then
        echo "${CONNECTOR_PREFIX}${connector_name} does NOT exist"
        all_present=1
      fi
    done

    return "${all_present}"
  fi

}

function validate_connectors_exist() {
  local connector_name
  for connector_name in "${CONNECTORS_ARRAY[@]}"; do
    connector_image_dir="${CONNECTOR_IMAGES_DIR}/${connector_name}"
    if [[ ! -d "${connector_image_dir}" ]]; then
      print_error_and_exit "Connector image directory ${connector_image_dir} does NOT exist"
    fi
  done

}

#######################################
# Appends a property value pair to the given property file.
# Arguments:
#   1. The file path to the properties file
#   2. The property value pair e.g. "name=value"
#######################################
function add_to_properties_file() {
  local property="${1}"
  local properties_file="${2}"

  {
    echo
    echo "${property}"
  } >>"${properties_file}"
}

function add_data_source_properties_if_necessary() {
  local properties_file="${1}"
  local topology_id
  local datasource_name

  if [[ "${DEPLOYMENT_PATTERN}" != "i2c" ]]; then
    topology_id="infostore"
    datasource_name="Information Store"
  else
    topology_id="opalDAOD"
    datasource_name="Opal DAOD"
  fi

  if ! grep -xq "DataSourceName=.*" "${properties_file}"; then
    add_to_properties_file "DataSourceName=${datasource_name}" "${properties_file}"
  fi
  if ! grep -xq "TopologyId=.*" "${properties_file}"; then
    add_to_properties_file "TopologyId=${topology_id}" "${properties_file}"
  fi
}

function get_topology_id() {
  local topology_id

  if [[ "${DEPLOYMENT_PATTERN}" != "i2c" ]]; then
    topology_id="infostore"
  else
    topology_id="opalDAOD"
  fi
  echo "${topology_id}"
}

function create_dsid_properties_for_deployment_pattern() {
  local dsid_properties_file_path="${1}"
  local dsid_deployment_pattern_properties_file_path
  local topology_id

  topology_id="$(get_topology_id)"
  dsid_deployment_pattern_properties_file_path="${LOCAL_CONFIG_DIR}/environment/dsid/dsid.${topology_id}.properties"
  mv "${dsid_properties_file_path}" "${dsid_deployment_pattern_properties_file_path}"

  add_data_source_properties_if_necessary "${dsid_deployment_pattern_properties_file_path}"
}

#######################################
# Create .configuration folder that is used by the i2 tools
# Arguments:
#   None
#######################################
function create_mounted_config_structure() {
  local FRAGMENTS_PATH="${LOCAL_CONFIG_DIR}/fragments"
  local OPAL_SERVICES_IS_CLASSES_PATH="${FRAGMENTS_PATH}/opal-services-is/WEB-INF/classes"
  local OPAL_SERVICES_CLASSES_PATH="${FRAGMENTS_PATH}/opal-services/WEB-INF/classes"
  local OPAL_SERVICES_PLUGINS_PATH="${FRAGMENTS_PATH}/opal-services/plugins"
  local COMMON_PATH="${FRAGMENTS_PATH}/common"
  local COMMON_CLASSES_PATH="${COMMON_PATH}/WEB-INF/classes"
  local ENV_COMMON_PATH="${LOCAL_CONFIG_DIR}/environment/common"
  local LIVE_PATH="${LOCAL_CONFIG_DIR}/live"
  local LIBERTY_PATH="${LOCAL_CONFIG_DIR}/liberty"
  local LOG4J_PATH="${LOCAL_CONFIG_DIR}/i2-tools/classes"
  local topology_id
  local plugin_references_file="${LOCAL_USER_CONFIG_DIR}/plugin-references.json"

  # Create hidden configuration folder
  delete_folder_if_exists_and_create "${LOCAL_CONFIG_DIR}"
  cp -pr "${GENERATED_LOCAL_CONFIG_DIR}/." "${LOCAL_CONFIG_DIR}"

  # Add jdbc drivers from pre-reqs folder
  delete_folder_if_exists_and_create "${ENV_COMMON_PATH}"

  # Recreate structure and copy right files
  mkdir -p "${LOG4J_PATH}" "${ENV_COMMON_PATH}" "${OPAL_SERVICES_IS_CLASSES_PATH}" "${OPAL_SERVICES_CLASSES_PATH}" "${COMMON_CLASSES_PATH}" "${LIVE_PATH}" "${LIBERTY_PATH}"
  cp -pr "${PRE_REQS_DIR}/jdbc-drivers" "${ENV_COMMON_PATH}"
  mv "${LOCAL_CONFIG_DIR}/analyze-settings.properties" \
    "${LOCAL_CONFIG_DIR}/analyze-connect.properties" \
    "${LOCAL_CONFIG_DIR}/ApolloServerSettingsMandatory.properties" \
    "${LOCAL_CONFIG_DIR}/ApolloServerSettingsConfigurationSet.properties" \
    "${LOCAL_CONFIG_DIR}/schema-charting-schemes.xml" \
    "${LOCAL_CONFIG_DIR}/schema.xml" "${LOCAL_CONFIG_DIR}/security-schema.xml" \
    "${LOCAL_CONFIG_DIR}/mapping-configuration.json" \
    "${LOCAL_CONFIG_DIR}/log4j2.xml" "${COMMON_CLASSES_PATH}"
  mv "${LOCAL_CONFIG_DIR}/schema-results-configuration.xml" \
    "${LOCAL_CONFIG_DIR}/schema-vq-configuration.xml" \
    "${LOCAL_CONFIG_DIR}/schema-source-reference-schema.xml" \
    "${LOCAL_CONFIG_DIR}/command-access-control.xml" \
    "${LOCAL_CONFIG_DIR}/DiscoSolrConfiguration.properties" \
    "${LOCAL_CONFIG_DIR}/connectors-template.json" \
    "${OPAL_SERVICES_CLASSES_PATH}"
  mv "${LOCAL_CONFIG_DIR}/InfoStoreNamesDb2.properties" \
    "${LOCAL_CONFIG_DIR}/InfoStoreNamesSQLServer.properties" \
    "${LOCAL_CONFIG_DIR}/InfoStoreNamesPostgres.properties" \
    "${OPAL_SERVICES_IS_CLASSES_PATH}"
  mv "${LOCAL_CONFIG_DIR}/fmr-match-rules.xml" "${LOCAL_CONFIG_DIR}/system-match-rules.xml" \
    "${LOCAL_CONFIG_DIR}/highlight-queries-configuration.xml" "${LOCAL_CONFIG_DIR}/geospatial-configuration.json" \
    "${LOCAL_CONFIG_DIR}/type-access-configuration.xml" \
    "${LIVE_PATH}"
  mv "${LOCAL_CONFIG_DIR}/privacyagreement.html" "${COMMON_PATH}"
  if [[ -f "${LOCAL_CONFIG_DIR}/server.extensions.xml" ]]; then
    mv "${LOCAL_CONFIG_DIR}/server.extensions.xml" "${LIBERTY_PATH}"
  fi
  if [[ -f "${LOCAL_CONFIG_DIR}/server.extensions.dev.xml" ]]; then
    mv "${LOCAL_CONFIG_DIR}/server.extensions.dev.xml" "${LIBERTY_PATH}"
  fi
  if [[ -f "${LOCAL_CONFIG_DIR}/user.registry.xml" ]]; then
    mv "${LOCAL_CONFIG_DIR}/user.registry.xml" "${LIBERTY_PATH}"
  fi
  rm "${LOCAL_CONFIG_DIR}/extension-references.json" &>/dev/null || true
  rm "${LOCAL_CONFIG_DIR}/plugin-references.json" &>/dev/null || true

  create_dsid_properties_for_deployment_pattern "${LOCAL_CONFIG_DIR}/environment/dsid/dsid.properties"

  # Move all outstanding .properties files into the common classes dir
  find "${LOCAL_CONFIG_DIR}" -maxdepth 1 -name "*.properties" -exec mv -t "${COMMON_CLASSES_PATH}" {} +

  # Add gateway schemas
  for gateway_short_name in "${!GATEWAY_SHORT_NAME_SET[@]}"; do
    mv "${LOCAL_CONFIG_DIR}/${gateway_short_name}-schema.xml" "${COMMON_CLASSES_PATH}"
    mv "${LOCAL_CONFIG_DIR}/${gateway_short_name}-schema-charting-schemes.xml" "${COMMON_CLASSES_PATH}"
  done

  # Copy plugins
  delete_folder_if_exists_and_create "${OPAL_SERVICES_PLUGINS_PATH}"
  readarray -t all_plugin_names < <(jq -r '.plugins[].name' <"${plugin_references_file}")
  if [[ "${#all_plugin_names[@]}" -gt 0 ]]; then
    for plugin_name in "${all_plugin_names[@]}"; do
      local plugin_dir="${PLUGINS_DIR}/${plugin_name}"
      if [[ ! -d "${plugin_dir}" ]]; then
        print_error_and_exit "Plugin directory ${plugin_dir} does NOT exist"
      fi
      create_folder "${OPAL_SERVICES_PLUGINS_PATH}/${plugin_name}"
      cp -pr "${plugin_dir}/." "${OPAL_SERVICES_PLUGINS_PATH}/${plugin_name}"
    done
  fi
}

function create_data_source_id() {
  local dsid_properties_file_path="${LOCAL_USER_CONFIG_DIR}/environment/dsid/dsid.properties"

  # Ensure this to work for previous release
  local old_dsid_properties_file_path="${LOCAL_USER_CONFIG_DIR}/environment/dsid/dsid.infostore.properties"
  if [[ -f "${old_dsid_properties_file_path}" ]]; then
    mv "${old_dsid_properties_file_path}" "${dsid_properties_file_path}"
  fi
  create_dsid_properties_file "${dsid_properties_file_path}"
}

function generate_boiler_plate_files() {
  local examples_dir="${LOCAL_TOOLKIT_DIR}/examples"
  local grafana_provisioning_dir="${examples_dir}/grafana/provisioning"
  local all_patterns_config_dir="${examples_dir}/configurations/all-patterns/configuration"
  local toolkit_common_classes_dir="${all_patterns_config_dir}/fragments/common/WEB-INF/classes"
  local toolkit_opal_services_classes_dir="${all_patterns_config_dir}/fragments/opal-services/WEB-INF/classes"

  cp -p "${toolkit_common_classes_dir}/ApolloServerSettingsMandatory.properties" "${GENERATED_LOCAL_CONFIG_DIR}"
  cp -p "${toolkit_common_classes_dir}/ApolloServerSettingsConfigurationSet.properties" "${GENERATED_LOCAL_CONFIG_DIR}"

  echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?><server>
    <webAppSecurity overrideHttpAuthMethod=\"FORM\" allowAuthenticationFailOverToAuthMethod=\"FORM\"  loginFormURL=\"opal/login.html\" loginErrorURL=\"opal/login.html?failed\"/>
    <featureManager>
        <feature>restConnector-2.0</feature>
    </featureManager>
    <applicationMonitor updateTrigger=\"mbean\" dropinsEnabled=\"false\"/>
    <config updateTrigger=\"mbean\"/>
    <administrator-role>
        <user>${I2_ANALYZE_ADMIN}</user>
    </administrator-role>
  </server>" >"${GENERATED_LOCAL_CONFIG_DIR}/server.extensions.dev.xml"

  mkdir -p "${GENERATED_LOCAL_CONFIG_DIR}/grafana/provisioning/datasources"
  cp -pr "${grafana_provisioning_dir}/." "${GENERATED_LOCAL_CONFIG_DIR}/grafana/provisioning"
  cp -p "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/templates/prometheus-datasource.yml" "${GENERATED_LOCAL_CONFIG_DIR}/grafana/provisioning/datasources/prometheus-datasource.yml"
}

function generate_connectors_artifacts() {
  local connector_references_file="${LOCAL_USER_CONFIG_DIR}/connector-references.json"

  local connector_definitions_file="${GENERATED_LOCAL_CONFIG_DIR}/connectors-template.json"
  local gateway_properties_file="${GENERATED_LOCAL_CONFIG_DIR}/analyze-connect.properties"
  local temp_file="${LOCAL_USER_CONFIG_DIR}/temp.json"

  #Find all connector names from connector-references.json and combine connector-definition from each connector together
  IFS=' ' read -ra all_connector_names <<<"$(jq -r '.connectors // empty | .[].name' <"${connector_references_file}" | xargs)"
  jq -n '. += {connectors: []}' >"${connector_definitions_file}"

  for connector_name in "${all_connector_names[@]}"; do
    local connector_image_dir="${CONNECTOR_IMAGES_DIR}/${connector_name}"
    if [[ ! -d "${connector_image_dir}" ]]; then
      print_error_and_exit "Connector image directory ${connector_image_dir} does NOT exist"
    fi

    connector_json=$(cat "${CONNECTOR_IMAGES_DIR}/${connector_name}/connector-definition.json")
    # Remove the "type" from the connectors-definition.json
    connector_json=$(jq -r 'del(.type)' <<<"$connector_json")
    jq -r --argjson connector_json "${connector_json}" \
      '.connectors += [$connector_json]' \
      <"${connector_definitions_file}" >"${temp_file}"
    mv "${temp_file}" "${connector_definitions_file}"
  done

  #Find all gateway schemas declared in connectors
  for connector_name in "${all_connector_names[@]}"; do
    gateway_short_name=$(jq -r '.gatewaySchema' <"${CONNECTOR_IMAGES_DIR}/${connector_name}/connector-definition.json")
    #May not declare a gateway
    if [[ -n ${gateway_short_name} ]]; then
      GATEWAY_SHORT_NAME_SET["${gateway_short_name}"]=$gateway_short_name
    fi
  done

  #Find all gateway schemas declared for this configuration
  readarray -t config_gateway_schemas < <(jq -r '.gatewaySchemas[].shortName' <"${connector_references_file}")

  for gateway_short_name in "${config_gateway_schemas[@]}"; do
    GATEWAY_SHORT_NAME_SET["${gateway_short_name}"]=$gateway_short_name
  done

  echo "# ------------------------ Gateway schemas and charting schemes -----------------------" >"${gateway_properties_file}"
  #Create configuration file
  for gateway_short_name in "${!GATEWAY_SHORT_NAME_SET[@]}"; do
    echo "Gateway.${gateway_short_name}.SchemaResource=${gateway_short_name}-schema.xml" >>"${gateway_properties_file}"
    echo "Gateway.${gateway_short_name}.ChartingSchemesResource=${gateway_short_name}-schema-charting-schemes.xml" >>"${gateway_properties_file}"
  done

  #Copy in gateway schemas
  for gateway_short_name in "${!GATEWAY_SHORT_NAME_SET[@]}"; do
    cp "${GATEWAY_SCHEMA_DIR}/${gateway_short_name}-schema.xml" "${GENERATED_LOCAL_CONFIG_DIR}"
    cp "${GATEWAY_SCHEMA_DIR}/${gateway_short_name}-schema-charting-schemes.xml" "${GENERATED_LOCAL_CONFIG_DIR}"
  done
}

#######################################
# Create .configuration-generated folder
# Arguments:
#   None
#######################################
function generate_artifacts() {
  # Create hidden configuration folder
  rm -rf "${GENERATED_LOCAL_CONFIG_DIR}"
  mkdir -p "${GENERATED_LOCAL_CONFIG_DIR}"
  rsync -qpr \
    --exclude "**.xsd" \
    --exclude "**/connector-references.json" \
    "${LOCAL_USER_CONFIG_DIR}/." "${GENERATED_LOCAL_CONFIG_DIR}"

  generate_connectors_artifacts
  generate_boiler_plate_files
}

function subtract_array_from_array() {
  local -n array1="$1"
  local -n array2="$2"
  local new_array

  readarray -t new_array < <(comm -13 --check-order <(printf '%s\n' "${array1[@]}" | LC_ALL=C sort) <(printf '%s\n' "${array2[@]}" | LC_ALL=C sort))

  echo "${new_array[*]}"
}

function build_extensions() {
  local extension_references_file="${LOCAL_USER_CONFIG_DIR}/extension-references.json"
  local extension_names
  local extension_args=()

  readarray -t extension_names < <(jq -r '.extensions[].name' <"${extension_references_file}")

  if [[ "${#extension_names}" -gt 0 ]]; then
    # Only attempt to rebuild extensions for the current config
    for extension_name in "${extension_names[@]}"; do
      extension_args+=("-i" "${extension_name}")
    done

    if [[ "${#extension_names[@]}" -gt 0 ]]; then
      print "Building i2 Analyze extensions"
      "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/scripts/build-extensions" -c "${CONFIG_NAME}" "${extension_args[@]}"
    fi
  fi
}

function build_plugins() {
  local plugin_references_file="${LOCAL_USER_CONFIG_DIR}/plugin-references.json"
  local plugin_names
  local plugin_args=()

  readarray -t plugin_names < <(jq -r '.plugins[].name' <"${plugin_references_file}")

  if [[ "${#plugin_names}" -gt 0 ]]; then
    # Only attempt to rebuild plugins for the current config
    for plugin_name in "${plugin_names[@]}"; do
      plugin_args+=("-i" "${plugin_name}")
    done

    if [[ "${#plugin_names[@]}" -gt 0 ]]; then
      "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/scripts/build-plugins" -c "${CONFIG_NAME}" "${plugin_args[@]}"
    fi
  fi
}

function set_dependencies_tag_if_necessary() {
  if [[ -z "${I2A_DEPENDENCIES_IMAGES_TAG}" ]]; then
    local version_tag
    version_tag=$(cat "${LOCAL_TOOLKIT_DIR}/scripts/version.txt")
    export I2A_DEPENDENCIES_IMAGES_TAG="${version_tag%%-*}"
  fi
  if [[ -z "${CONFIG_NAME}" ]]; then
    export I2A_LIBERTY_CONFIGURED_IMAGE_TAG="${I2A_DEPENDENCIES_IMAGES_TAG}"
  else
    export I2A_LIBERTY_CONFIGURED_IMAGE_TAG="${CONFIG_NAME}-${I2A_DEPENDENCIES_IMAGES_TAG}"
  fi
}

function update_core_secrets_volumes() {
  update_volume "${LOCAL_KEYS_DIR}/${LIBERTY1_HOST_NAME}" "${LIBERTY1_SECRETS_VOLUME_NAME}" "${CONTAINER_SECRETS_DIR}"
  update_volume "${LOCAL_KEYS_DIR}/${LIBERTY2_HOST_NAME}" "${LIBERTY2_SECRETS_VOLUME_NAME}" "${CONTAINER_SECRETS_DIR}"
  update_volume "${LOCAL_KEYS_DIR}/${ZK1_HOST_NAME}" "${ZK1_SECRETS_VOLUME_NAME}" "${CONTAINER_SECRETS_DIR}"
  update_volume "${LOCAL_KEYS_DIR}/${ZK2_HOST_NAME}" "${ZK2_SECRETS_VOLUME_NAME}" "${CONTAINER_SECRETS_DIR}"
  update_volume "${LOCAL_KEYS_DIR}/${ZK3_HOST_NAME}" "${ZK3_SECRETS_VOLUME_NAME}" "${CONTAINER_SECRETS_DIR}"
  update_volume "${LOCAL_KEYS_DIR}/${CONNECTOR1_HOST_NAME}" "${CONNECTOR1_SECRETS_VOLUME_NAME}" "${CONTAINER_SECRETS_DIR}"
  update_volume "${LOCAL_KEYS_DIR}/${CONNECTOR2_HOST_NAME}" "${CONNECTOR2_SECRETS_VOLUME_NAME}" "${CONTAINER_SECRETS_DIR}"
  update_volume "${LOCAL_KEYS_DIR}/${SOLR1_HOST_NAME}" "${SOLR1_SECRETS_VOLUME_NAME}" "${CONTAINER_SECRETS_DIR}"
  update_volume "${LOCAL_KEYS_DIR}/${SOLR2_HOST_NAME}" "${SOLR2_SECRETS_VOLUME_NAME}" "${CONTAINER_SECRETS_DIR}"
  update_volume "${LOCAL_KEYS_DIR}/${SOLR3_HOST_NAME}" "${SOLR3_SECRETS_VOLUME_NAME}" "${CONTAINER_SECRETS_DIR}"
  update_volume "${LOCAL_KEYS_DIR}/${SQL_SERVER_HOST_NAME}" "${SQL_SERVER_SECRETS_VOLUME_NAME}" "${CONTAINER_SECRETS_DIR}"
  update_volume "${LOCAL_KEYS_DIR}/${DB2_SERVER_HOST_NAME}" "${DB2_SERVER_SECRETS_VOLUME_NAME}" "${CONTAINER_SECRETS_DIR}"
  update_volume "${LOCAL_KEYS_DIR}/${POSTGRES_SERVER_HOST_NAME}" "${POSTGRES_SERVER_SECRETS_VOLUME_NAME}" "${CONTAINER_SECRETS_DIR}"
  update_volume "${LOCAL_KEYS_DIR}/${I2ANALYZE_HOST_NAME}" "${LOAD_BALANCER_SECRETS_VOLUME_NAME}" "${CONTAINER_SECRETS_DIR}"
  update_volume "${LOCAL_KEYS_DIR}/${PROMETHEUS_HOST_NAME}" "${PROMETHEUS_SECRETS_VOLUME_NAME}" "${CONTAINER_SECRETS_DIR}"
  update_volume "${LOCAL_KEYS_DIR}/${GRAFANA_HOST_NAME}" "${GRAFANA_SECRETS_VOLUME_NAME}" "${CONTAINER_SECRETS_DIR}"
}

function warn_root_dir_not_in_path() {
  local current_path

  current_path=$(pwd)
  if [[ "${current_path}" != "${ANALYZE_CONTAINERS_ROOT_DIR}"* && "${CI}" != "true" && "${DEV_MODE}" != "true" ]]; then
    echo "ANALYZE_CONTAINERS_ROOT_DIR=${ANALYZE_CONTAINERS_ROOT_DIR}"
    wait_for_user_reply "The current script path is not inside the set ANALYZE_CONTAINERS_ROOT_DIR. Are you sure you want to continue?"
  fi
}

function update_state_file() {
  local new_state="$1"
  print_info "Updating ${PREVIOUS_STATE_FILE_PATH} with state: ${new_state}"
  sed -i "s/STATE=.*/STATE=${new_state}/g" "${PREVIOUS_STATE_FILE_PATH}"
}

function add_liberty_feature() {
  local feature="$1"
  local file="$2"

  featureManagerCount=$(xmlstarlet sel -t -v "count(/server/featureManager)" "${file}")
  if [[ "${featureManagerCount}" != 0 ]]; then
    print_info "featureManager found in ${file##*/}"
  else
    print_info "featureManager NOT found in ${file##*/}. Adding a featureManager..."
    xmlstarlet edit -L --subnode "/server" --type elem -n "featureManager" \
      --update "/server/featureManager" --value " " "${file}"
  fi

  if xmlstarlet sel -Q -t -c \
    "/server/featureManager/feature[contains(text(),'${feature}')]" \
    "${file}"; then
    print_info "Feature ${feature} found in ${file##*/}"
    echo 0
    return
  else
    print_info "Adding feature ${feature} to file ${file##*/}"
    xmlstarlet edit -L \
      --subnode "/server/featureManager" --type elem -n "feature" \
      --update "/server/featureManager/feature[last()]" --value "${feature}" \
      "${file}"
    echo 1
    return
  fi
}

function ensure_license_accepted() {
  local license_name="$1"

  case "${license_name}" in
  "LIC_AGREEMENT")
    if [[ "${LIC_AGREEMENT}" == "ACCEPT" ]]; then
      return
    fi
    ;;
  "MSSQL_PID")
    # This is tied to the sql server image so it is easier to check for our shipped value instead of
    # the possible values that might change in the future
    if [[ "${MSSQL_PID}" != "REJECT" ]]; then
      return
    fi
    ;;
  "ACCEPT_EULA")
    if [[ "${ACCEPT_EULA}" == "Y" ]]; then
      return
    fi
    ;;
  "DB2_LICENSE")
    if [[ "${DB2_LICENSE}" == "accept" ]]; then
      return
    fi
    ;;
  *)
    print_error_and_exit "Unknown license ${license_name}"
    ;;
  esac
  print_error_and_exit "${license_name} needs to be accepted in the licenses.conf file"
}

function check_licenses_accepted_if_required() {
  local environment="$1"
  local deployment_pattern="$2"
  local db_dialect="$3"

  print "Checking Licenses Accepted"
  ensure_license_accepted "LIC_AGREEMENT"
  if [[ "${environment}" == "config-dev" ]]; then
    if [[ -z "${deployment_pattern}" ]]; then
      print_error_and_exit "checkLicenseAccepted requires a deployment pattern in config-dev"
    fi
    if [[ "${deployment_pattern}" == *"store"* ]]; then
      if [[ -z "${db_dialect}" ]]; then
        print_error_and_exit "checkLicenseAccepted requires a database dialect when deploying ISTORE"
      fi
      if [[ "${db_dialect}" == "db2" ]]; then
        ensure_license_accepted "DB2_LICENSE"
      elif [[ "${db_dialect}" == "sqlserver" ]]; then
        ensure_license_accepted "MSSQL_PID"
        ensure_license_accepted "ACCEPT_EULA"
      fi
    fi
  elif [[ "${environment}" == "pre-prod" ]]; then
    ensure_license_accepted "MSSQL_PID"
    ensure_license_accepted "ACCEPT_EULA"
  fi
}

function configure_prometheus_for_pre_prod() {
  local prometheus_scheme="http"
  local liberty_scheme="http"
  if [[ "${PROMETHEUS_SSL_CONNECTION}" == "true" ]]; then
    prometheus_scheme="https"
  fi
  if [[ "${LIBERTY_SSL_CONNECTION}" == "true" ]]; then
    liberty_scheme="https"
  fi

  sed \
    -e "s/\${PROMETHEUS_SCHEME}/${prometheus_scheme}/g" \
    -e "s/\${LIBERTY_SCHEME}/${liberty_scheme}/g" \
    -e "s/\${LIBERTY1_STANZA}/${LIBERTY1_STANZA}/g" \
    -e "s/\${LIBERTY2_STANZA}/${LIBERTY2_STANZA}/g" \
    "${LOCAL_PROMETHEUS_CONFIG_DIR}/prometheus-template.yml" >"${LOCAL_PROMETHEUS_CONFIG_DIR}/prometheus.yml"
}

function create_license_configuration() {
  local license_conf_template="${ANALYZE_CONTAINERS_ROOT_DIR}/utils/templates/licenses.conf"
  local license_conf="${ANALYZE_CONTAINERS_ROOT_DIR}/licenses.conf"
  declare -A licenses

  if [[ ! -f "${ANALYZE_CONTAINERS_ROOT_DIR}/licenses.conf" ]]; then
    cp -p "${license_conf_template}" "${license_conf}"
  else
    licenses=()
    while IFS= read -r line; do
      [[ "${line}" =~ ^#.* ]] && continue
      [[ -z "${line}" ]] && continue
      licenses["${line%%=*}"]="${line#*=}"
    done <"${license_conf_template}"

    # Add empty new line if none
    if [[ -n "$(tail -c1 "${license_conf}")" ]]; then
      echo >>"${license_conf}"
    fi
    for prop in "${!licenses[@]}"; do
      if grep -q -E -o -m 1 "${prop}" <"${license_conf}"; then
        continue
      fi
      echo "${prop}=${licenses["${prop}"]}" >>"${license_conf}"
    done
  fi
}

function get_check_sum_of_dir() {
  local path="$1"
  local exclude="$2"
  local extra_args=()

  if [[ -n "${exclude}" ]]; then
    extra_args=(-not -path "${exclude}")
  fi

  # Get the checksum of each file then do checksum of that
  find -L "${path}" -type f "${extra_args[@]}" -exec sha1sum {} \; | awk '{print $1}' | sort | sha1sum
}

function check_connector_changed() {
  local connector_name="$1"
  local old_checksum=""
  local new_checksum

  if [[ -f "${PREVIOUS_CONNECTOR_IMAGES_DIR}/${connector_name}.sha512" ]]; then
    old_checksum="$(cat "${PREVIOUS_CONNECTOR_IMAGES_DIR}/${connector_name}.sha512")"
  fi

  new_checksum="$(get_check_sum_of_dir "${CONNECTOR_IMAGES_DIR}/${connector_name}")"

  if [[ "${old_checksum}" == "${new_checksum}" ]]; then
    return 1
  else
    create_folder "${PREVIOUS_CONNECTOR_IMAGES_DIR}"
    echo "${new_checksum}" >"${PREVIOUS_CONNECTOR_IMAGES_DIR}/${connector_name}.sha512.new"
    return 0
  fi
}

function update_connector_url_mappings() {
  local connector_url_mappings_file="${CONNECTOR_IMAGES_DIR}/connector-url-mappings-file.json"
  local temp_file="${CONNECTOR_IMAGES_DIR}/temp.json"
  local connector_type connector_name connector_id base_url configuration_path connector_image_dir
  local connector_tag connector_fqdn

  local connector_references_file="${LOCAL_USER_CONFIG_DIR}/connector-references.json"

  readarray -t all_connector_names < <(jq -r '.connectors[].name' <"${connector_references_file}")

  for connector_name in "${all_connector_names[@]}"; do
    connector_image_dir="${CONNECTOR_IMAGES_DIR}/${connector_name}"
    connector_definition_file_path="${connector_image_dir}/connector-definition.json"

    # Definitions
    configuration_path=$(jq -r '.configurationPath' <"${connector_definition_file_path}")
    connector_id=$(jq -r '.id' <"${connector_definition_file_path}")
    connector_type=$(jq -r '.type' <"${connector_definition_file_path}")
    connector_exists=$(jq -r --arg connector_id "${connector_id}" 'any(.[]; .id==$connector_id)' <"${connector_url_mappings_file}")

    if [[ "${connector_type}" != "${EXTERNAL_CONNECTOR_TYPE}" ]]; then
      connector_tag=$(jq -r '.tag' <"${connector_image_dir}/connector-version.json")
      connector_fqdn="${connector_name}-${connector_tag}.${DOMAIN_NAME}"
      base_url="https://${connector_fqdn}:3443"
    else
      base_url=$(jq -r '.baseUrl' <"${connector_definition_file_path}")
    fi

    # Update connector-url-mappings-file.json file
    if [[ "${connector_exists}" == "true" ]]; then
      # Update
      jq -r \
        --arg base_url "${base_url}" \
        --arg connector_id "${connector_id}" \
        --arg config_path "${configuration_path}" \
        ' .[] |= (select(.id==$connector_id) |= (.baseUrl = $base_url | .configPath = $config_path))' \
        <"${connector_url_mappings_file}" >"${temp_file}"
    else
      # Insert
      jq -r \
        --arg base_url "${base_url}" \
        --arg connector_id "${connector_id}" \
        --arg config_path "${configuration_path}" \
        '. += [{id: $connector_id, baseUrl: $base_url, configPath: $config_path}]' \
        <"${connector_url_mappings_file}" >"${temp_file}"
    fi
    mv "${temp_file}" "${connector_url_mappings_file}"
  done

  validate_connector_url_mappings
}

function deploy_connector() {
  local connector_name="$1"
  local connector_image_dir="${CONNECTOR_IMAGES_DIR}/${connector_name}"
  local temp_file="${CONNECTOR_IMAGES_DIR}/temp.json"
  local connector_type

  # Validation
  connector_definition_file_path="${connector_image_dir}/connector-definition.json"
  validate_connector_definition "${connector_definition_file_path}"

  # Definitions
  configuration_path=$(jq -r '.configurationPath' <"${connector_definition_file_path}")
  connector_id=$(jq -r '.id' <"${connector_definition_file_path}")
  connector_type=$(jq -r '.type' <"${connector_definition_file_path}")
  validate_connector_secrets "${connector_name}"

  # Run connector if not external
  if [[ "${connector_type}" != "${EXTERNAL_CONNECTOR_TYPE}" ]]; then
    local connector_tag connector_fqdn

    connector_tag=$(jq -r '.tag' <"${connector_image_dir}/connector-version.json")
    connector_fqdn="${connector_name}-${connector_tag}.${DOMAIN_NAME}"

    delete_container "${CONNECTOR_PREFIX}${connector_name}"

    # Start up the connector
    run_connector "${CONNECTOR_PREFIX}${connector_name}" "${connector_fqdn}" "${connector_name}" "${connector_tag}" "${connector_id}"
    wait_for_connector_to_be_live "${connector_fqdn}" "${configuration_path}"
  fi
}

function validate_connector_definition() {
  local connector_definition_file_path="$1"
  local not_valid_error_message="${connector_definition_file_path} is NOT valid"
  local valid_json

  print "Validating ${connector_definition_file_path}"

  type="$(jq -r type <"${connector_definition_file_path}" || true)"

  if [[ "${type}" == "object" ]]; then
    valid_json=$(jq -r '. | select(has("id") and has("name") and has("description") and has("gatewaySchema") and has("configurationPath") and (has("type")==false // .type=="external" and has("baseUrl") // .type!="external"))' <"${connector_definition_file_path}")
    if [[ -z "${valid_json}" ]]; then
      print_error_and_exit "${not_valid_error_message}"
    fi
  else
    print_error_and_exit "${not_valid_error_message}"
  fi
}

function validate_connector_secrets() {
  local connector_name="$1"
  local connector_secrets_file_path="${LOCAL_KEYS_DIR}/${connector_name}"
  local not_valid_error_message="Secrets have not been created for the ${connector_name} connector"

  print "Validating ${connector_secrets_file_path}"
  if [ ! -d "${connector_secrets_file_path}" ]; then
    print_error_and_exit "${not_valid_error_message}"
  fi
}

function validate_connector_url_mappings() {
  local connector_url_mappings_file="${CONNECTOR_IMAGES_DIR}/connector-url-mappings-file.json"
  local not_valid_error_message="${connector_url_mappings_file} is NOT valid"
  local valid_json json_type json_length

  print "Validating ${connector_url_mappings_file}"

  json_type="$(jq -r 'type' <"${connector_url_mappings_file}" || true)"
  json_length="$(jq -r 'length' <"${connector_url_mappings_file}" || true)"

  if [[ "${json_type}" == "array" ]]; then
    if [[ "${json_length}" -eq 0 ]]; then
      return # Valid empty array
    fi
    valid_json=$(jq -r '.[] | select(has("id") and has("baseUrl") and has("configPath"))' <"${connector_url_mappings_file}")
    if [[ -z "${valid_json}" ]]; then
      print_error_and_exit "${not_valid_error_message}"
    fi
  else
    print_error_and_exit "${not_valid_error_message}"
  fi
}

function validate_parameters_not_empty() {
  local param_count=1
  for param in "$@"; do
    if [[ -z "${param}" ]]; then
      print_error_and_exit "Parameter number ${param_count} is empty"
    fi
    ((param_count++))
  done
}

function validate_parameters() {
  local expected_param_count="$1"
  local actual_param_count=$(("$#" - 1))

  if [[ "${actual_param_count}" -lt "${expected_param_count}" ]]; then
    print_error_and_exit "The number of parameters (${actual_param_count}) is not the same as the expected number of parameters (${expected_param_count})."
  fi

  validate_parameters_not_empty "${@:2}"
}

#######################################
# Creates an asset array for an asset type.
# Arguments:
#   1. The asset type e.g. "connector"
#   2. The assets directory
#   3. (Optional) Directory to be skipped
#######################################
function build_asset_array() {
  local asset_type="$1"
  local assets_dir="$2"
  local skip_dir="$3"

  ASSETS_ARRAY=()
  if [[ "${INCLUDED_ASSETS[*]}" ]]; then
    # if included asset provided assign them to the ASSETS_ARRAY
    ASSETS_ARRAY+=("${INCLUDED_ASSETS[@]}")
  else
    # All assets
    for asset_dir in "${ANALYZE_CONTAINERS_ROOT_DIR}/${assets_dir}"/*; do
      [[ ! -d "${asset_dir}" ]] && continue
      asset_name=$(basename "${asset_dir}")
      if [[ -n "${skip_dir}" ]]; then
        [[ "${asset_name}" == "${skip_dir}" ]] && continue
      fi
      ASSETS_ARRAY+=("${asset_name}")
    done
    # All assets minus excluded assets
    if [[ -n "${EXCLUDED_ASSETS[*]}" ]]; then
      for excluded_asset in "${EXCLUDED_ASSETS[@]}"; do
        for i in "${!ASSETS_ARRAY[@]}"; do
          if [[ ${ASSETS_ARRAY[i]} == "${excluded_asset}" ]]; then
            unset 'ASSETS_ARRAY[i]'
          fi
        done
      done
    fi
  fi

  case "${asset_type}" in
  "config")
    CONFIGS_ARRAY=("${ASSETS_ARRAY[@]}")
    ;;
  "connector")
    CONNECTORS_ARRAY=("${ASSETS_ARRAY[@]}")
    ;;
  "extension")
    EXTENSIONS_ARRAY=("${ASSETS_ARRAY[@]}")
    ;;
  "plugin")
    PLUGINS_ARRAY=("${ASSETS_ARRAY[@]}")
    ;;
  esac
}

function pull_base_images() {
  print "Pull base images"
  docker pull "${JAVA_IMAGE_NAME}:${JAVA_IMAGE_VERSION}"
  docker pull "${REDHAT_UBI_IMAGE_NAME}:${REDHAT_UBI_IMAGE_VERSION}"
  docker pull "haproxy:${HA_PROXY_IMAGE_VERSION}"
  docker pull "i2group/i2eng-liberty:${LIBERTY_VERSION}"
  docker pull "i2group/i2eng-solr:${SOLR_VERSION}"
  docker pull "${ZOOKEEPER_IMAGE_NAME}:${ZOOKEEPER_VERSION}"
  docker pull "i2group/i2eng-prometheus:${PROMETHEUS_VERSION}"
  docker pull "grafana/grafana-oss:${GRAFANA_VERSION}"
  docker pull "mcr.microsoft.com/mssql/rhel/server:${SQL_SERVER_IMAGE_VERSION}"
  docker pull "${POSTGRES_SERVER_IMAGE_NAME}:${POSTGRES_IMAGE_VERSION}"
  docker pull "${NODEJS_IMAGE_NAME}:${NODEJS_IMAGE_VERSION}"
  docker pull "${SPRINGBOOT_IMAGE_NAME}:${SPRINGBOOT_IMAGE_VERSION}"
}

# @description Checks if a string is contained in an array of strings.
#
# @arg $1 string String to check
# @arg $2 array  Array of strings to check against
#
# @exitcode 0 If found.
# @exitcode 1 If not found.
function is_string_in_array() {
  local text="$1"
  local -n array="$2"

  # shellcheck disable=SC2076
  if [[ " ${array[*]} " =~ " ${text} " ]]; then
    return 0
  else
    return 1
  fi
}

function source_file_or_next() {
  local -n files_array="$1"
  for file in "${files_array[@]}"; do
    if source "${file}" >/dev/null 2>&1; then
      return 0
    fi
  done
  print_error_and_exit "Could not source any of the possible files: ${files_array[*]}"
}

function update_grafana_dashboard_volume() {
  local grafana_dashboards_dir="/etc/grafana/dashboards"
  update_volume "${LOCAL_GRAFANA_CONFIG_DIR}/dashboards" "${GRAFANA_DASHBOARDS_VOLUME_NAME}" "${grafana_dashboards_dir}"
}

function install_jar_to_maven_local_if_necessary() {
  local group_id="${1}"
  local artifact_id="${2}"
  local version="${3}"
  local file_path="${4}"

  if ! mvn dependency:get -Dartifact="${group_id}:${artifact_id}:${version}" >/dev/null; then
    mvn install:install-file -Dfile="${file_path}" -DgroupId="${group_id}" -DartifactId="${artifact_id}" -Dversion="${version}" -Dpackaging=jar
  fi
}
function setup_i2_analyze_maven_local() {
  local libPath="${TOOLKIT_APPLICATION_DIR}/shared/lib"

  print "Ensure i2 Analyze dependencies are installed..."

  install_jar_to_maven_local_if_necessary "com.i2group" "apollo-legacy" "${SUPPORTED_I2ANALYZE_VERSION}" "${libPath}/ApolloLegacy.jar"
  install_jar_to_maven_local_if_necessary "com.i2group" "disco-api" "${SUPPORTED_I2ANALYZE_VERSION}" "${libPath}/disco-api-9.2.jar"
  install_jar_to_maven_local_if_necessary "com.i2group" "daod" "${SUPPORTED_I2ANALYZE_VERSION}" "${libPath}/Daod.jar"
  install_jar_to_maven_local_if_necessary "com.i2group" "disco-utils" "${SUPPORTED_I2ANALYZE_VERSION}" "${libPath}/DiscoUtils.jar"

  pushd "${ANALYZE_CONTAINERS_ROOT_DIR}/i2a-extensions" >/dev/null || print_error_and_exit "Cannot cd into i2a-extensions. Exiting."
  mvn install
  popd >/dev/null || print_error_and_exit "Cannot cd out of i2a-extensions. Exiting."
}

function stop_db_server() {
  local dialect="${1:-"${DB_DIALECT}"}"
  case "${dialect}" in
  sqlserver)
    print "Stopping SQL Server container"
    docker stop "${SQL_SERVER_CONTAINER_NAME}"
    ;;
  db2)
    print "Stopping Db2 Server container"
    docker stop "${DB2_SERVER_CONTAINER_NAME}"
    ;;
  postgres)
    print "Stopping Postgres Server container"
    docker stop "${POSTGRES_SERVER_CONTAINER_NAME}"
    ;;
  esac
}

function start_db_server() {
  case "${DB_DIALECT}" in
  sqlserver)
    print "Starting SQL Server container"
    docker start "${SQL_SERVER_CONTAINER_NAME}"
    ;;
  db2)
    print "Starting Db2 Server container"
    docker start "${DB2_SERVER_CONTAINER_NAME}"
    ;;
  postgres)
    print "Starting Postgres Server container"
    docker start "${POSTGRES_SERVER_CONTAINER_NAME}"
    ;;
  esac
  wait_for_db_to_be_live
}

function wait_for_db_to_be_live() {
  case "${DB_DIALECT}" in
  sqlserver)
    if [[ "${VERSION}" < "2.4.1" ]]; then
      waitForSQLServerToBeLive
    else
      wait_for_sql_server_to_be_live
    fi
    ;;
  db2)
    wait_for_db2_server_to_be_live
    ;;
  postgres)
    wait_for_postgres_server_to_be_live
    ;;
  esac
}

function handle_db_initiation_on_pattern_change() {
  local db_container_status
  local server_name

  case "${DB_DIALECT}" in
  sqlserver)
    server_name="SQL Server"
    db_container_status="$(docker ps -a --format "{{.Status}}" -f network="${DOMAIN_NAME}" -f name="^${SQL_SERVER_CONTAINER_NAME}$")"
    ;;
  db2)
    server_name="Db2 Server"
    db_container_status="$(docker ps -a --format "{{.Status}}" -f network="${DOMAIN_NAME}" -f name="^${DB2_SERVER_CONTAINER_NAME}$")"
    ;;
  postgres)
    server_name="Postgres Server"
    db_container_status="$(docker ps -a --format "{{.Status}}" -f network="${DOMAIN_NAME}" -f name="^${POSTGRES_SERVER_CONTAINER_NAME}$")"
    ;;
  esac

  if [[ "${db_container_status%% *}" == "Up" ]]; then
    print "${server_name} container is already running"
    update_schema
  elif [[ "${db_container_status%% *}" == "Exited" ]]; then
    start_db_server
    update_schema
  else
    print "Removing ${server_name} volumes"
    case "${DB_DIALECT}" in
    sqlserver)
      docker volume rm -f "${SQL_SERVER_VOLUME_NAME}" "${SQL_SERVER_BACKUP_VOLUME_NAME}"
      update_state_file 1
      initialize_sql_server
      ;;
    db2)
      docker volume rm -f "${DB2_SERVER_VOLUME_NAME}" "${DB2_SERVER_BACKUP_VOLUME_NAME}"
      update_state_file 1
      initialize_db2_server
      ;;
    postgres)
      docker volume rm -f "${POSTGRES_SERVER_VOLUME_NAME}" "${POSTGRES_SERVER_BACKUP_VOLUME_NAME}"
      update_state_file 1
      initialize_postgres_server
      ;;
    esac

    update_state_file 2
  fi
}

function clear_search_index() {
  print "Clearing the search index"
  # The curl command uses the container's local environment variables to obtain the SOLR_ADMIN_DIGEST_USERNAME and SOLR_ADMIN_DIGEST_PASSWORD.
  # To stop the variables being evaluated in this script, the variables are escaped using backslashes (\) and surrounded in double quotes (").
  # Any double quotes in the curl command are also escaped by a leading backslash.
  run_solr_client_command bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/main_index/update?commit=true\" -H Content-Type:text/xml --data-binary \"<delete><query>*:*</query></delete>\""
  run_solr_client_command bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/match_index1/update?commit=true\" -H Content-Type:text/xml --data-binary \"<delete><query>*:*</query></delete>\""
  run_solr_client_command bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/match_index2/update?commit=true\" -H Content-Type:text/xml --data-binary \"<delete><query>*:*</query></delete>\""
  run_solr_client_command bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/chart_index/update?commit=true\" -H Content-Type:text/xml --data-binary \"<delete><query>*:*</query></delete>\""
  run_solr_client_command bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/daod_index/update?commit=true\" -H Content-Type:text/xml --data-binary \"<delete><query>*:*</query></delete>\""
  run_solr_client_command bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/highlight_index/update?commit=true\" -H Content-Type:text/xml --data-binary \"<delete><query>*:*</query></delete>\""
  run_solr_client_command bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/vq_index/update?commit=true\" -H Content-Type:text/xml --data-binary \"<delete><query>*:*</query></delete>\""

  # Remove the collection properties from ZooKeeper
  run_solr_client_command "/opt/solr/server/scripts/cloud-scripts/zkcli.sh" -zkhost "${ZK_HOST}" -cmd clear "/collections/main_index/collectionprops.json"
  run_solr_client_command "/opt/solr/server/scripts/cloud-scripts/zkcli.sh" -zkhost "${ZK_HOST}" -cmd clear "/collections/match_index1/collectionprops.json"
  run_solr_client_command "/opt/solr/server/scripts/cloud-scripts/zkcli.sh" -zkhost "${ZK_HOST}" -cmd clear "/collections/match_index2/collectionprops.json"
  run_solr_client_command "/opt/solr/server/scripts/cloud-scripts/zkcli.sh" -zkhost "${ZK_HOST}" -cmd clear "/collections/chart_index/collectionprops.json"
}

function check_valid_config_name() {
  local config_name="$1"
  local root_dir="${2:-"${ANALYZE_CONTAINERS_ROOT_DIR}"}"
  if [[ -z "${config_name}" ]]; then
    print_usage 1
  fi

  if [[ ! "${config_name}" =~ ^[0-9a-zA-Z_+\-]+$ ]]; then
    printf "\e[31mERROR: Config '%s' name cannot contain special characters or spaces. Allowed characters are 0-9a-zA-Z_+-\n" "${config_name}" >&2
    printf "\e[0m" >&2
    print_usage 1
  fi

  if [[ ! -d "${root_dir}/configs/${config_name}" ]]; then
    printf "\e[31mERROR: Config '%s' name does not exist in '%s' directory." \
      "${config_name}" "${root_dir}/configs" >&2
    printf "\e[0m" >&2
    print_usage 1
  fi
}
###############################################################################
# End of function definitions.                                                #
###############################################################################
