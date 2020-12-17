DROP VIEW IS_Public.E_Person_MPVDV
go

CREATE VIEW IS_Public.E_Person_MPVDV
AS

            SELECT item_id, p_unique_reference, p_title, p_first_given_name, p_middle_name, p_family_name, p_maiden_name, p_suffix, p_alias, p_aka, p_date_of_birth, p_gender, p_place_of_birth, p_deceased, p_identification_number, p_identification_type, p_issued_by, p_marital_status, p_age, p_nationality, p_citizenship, p_ethnicity, p_religion, p_ideology, p_accent, p_build, p_height_from, p_height_to, p_height_units_, p_shoe_size, p_shoe_size_units_, p_handedness, p_eye_wear, p_eye_position, p_eye_color, p_hair_type, p_hair_color, p_facial_hair, p_habits, p_occupation, p_mark_type, p_body_part, p_body_position, p_description_of_mark, p_spoken_language, p_type, p_description, p_image_description, p_additional_informatio, p0_date_and_time_of_deat, p1_date_and_time_of_deat, p2_date_and_time_of_deat, p3_date_and_time_of_deat, p0_issued_date_and_time, p1_issued_date_and_time, p2_issued_date_and_time, p3_issued_date_and_time
            FROM  (
                      SELECT MCV.*,
                             ROW_NUMBER ( ) OVER (PARTITION BY  MCV.item_id
                                 ORDER BY CASE ingestion_source_name
                                              WHEN 'EXAMPLE_1' THEN 1
                                              WHEN 'EXAMPLE_2' THEN 2
                                              ELSE 3
                                     END
                                 ) AS partition_row_number
                      FROM IS_Public.E_Person_MCV AS MCV
                               INNER JOIN IS_Public.E_Person_STP AS STP
                                          ON MCV.item_id = STP.item_id
                  ) AS P
            WHERE partition_row_number = 1
go

