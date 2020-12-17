#!/bin/bash
# (C) Copyright IBM Corporation 2018, 2020.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License 2.0 which is available at
# http://www.eclipse.org/legal/epl-2.0.
#
# SPDX-License-Identifier: EPL-2.0

# usage: resolve_env_var VAR [default]
#    e.g:
#       resolve_env_var 'SA_PASSWORD'
#       resolve_env_var 'SA_PASSWORD' 'aStrongPAssw0rd'
#
#    If a matching environment variable is present with _FILE appended to it's name, this file's
#    contents will be used, otherwise if an environment variable matching exactly is present
#    the literal value of the environment variable will be used.
#
#    If neither of the above is true a default will be used if set as the second argument, otherwise
#    no value will be set.
file_env() {
	local targetVar="$1"
	local fileVar="${targetVar}_FILE"
	local def="${2:-}"
	if [ "${!targetVar:-}" ] && [ "${!fileVar:-}" ]; then
		echo >&2 "Error: both $targetVar and $fileVar are set, only one is allowed."
		exit 1
	fi
	local resolvedVal="$def"
	if [ "${!targetVar:-}" ]; then
		resolvedVal="${!targetVar}"
	elif [ "${!fileVar:-}" ]; then
		resolvedVal="$(< "${!fileVar}")"
	fi
	export "$targetVar"="$resolvedVal"
	unset "$fileVar"
}