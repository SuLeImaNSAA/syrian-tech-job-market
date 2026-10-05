# Source data

The supplied `jobs_raw.csv` is included and was used to generate `source_profile.json`. Run the import command in the root README to load it into PostgreSQL.

Expected fields, in order:

```text
job_title,company_name,origin_type,city,country,source,experience_level,experience_years_min,experience_years_max,job_type,posted_date,salary,skills,description
```

Add a data dictionary and a source/collection description after confirming them against the original file.
