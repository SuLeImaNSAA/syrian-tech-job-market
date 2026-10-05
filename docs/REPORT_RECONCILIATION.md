# Reconcile the original Power BI report

The original one-page PBIX visualized a PostgreSQL model made with exploratory `base.sql`. The supplied source CSV has 203 rows. Direct counts of distinct source postings differ from some of the report's skill counts:

| Skill | Original report | Distinct source postings |
| --- | ---: | ---: |
| REST API | 109 | 69 |
| Git | 102 | 66 |
| CI/CD | 81 | 52 |
| Python | 76 | 49 |

The original load of `job_skills` joined `jobs` and `raw_jobs` on the job title alone. Repeated titles occur many times in the CSV, so one posting's skills can attach to another posting. The new model uses `jobs.raw_job_id = raw_jobs.raw_job_id` and a unique `(job_id, skill_id)` key.

The original salary update also paired rows using two unordered `ROW_NUMBER() OVER ()` expressions. The new transform parses each salary from the same `raw_jobs` row. There are ten numeric salaries/ranges in the CSV, but individual salary assignments in the old PBIX cannot be trusted until refreshed.

The 46 junior postings are a valid direct count of `experience_level = 'Junior'`. Seventeen of those rows have no `experience_years_max`, so grouping by an imputed maximum changes the interpretation of the original 23/23 experience chart. The new analysis should show the stated **minimum years** and a separate missing-maximum count.

## Power BI update checklist

1. Load the revised PostgreSQL model and inspect relationships. Link `jobs.id` to `job_skills.job_id` and `skills.id` to `job_skills.skill_id`.
2. Set the top-skills chart to count **distinct job IDs** by skill. Check REST API = 69, Git = 66, CI/CD = 52, Python = 49 on the full dataset before filters.
3. Check total jobs = 203, canonical companies = 70, salary disclosures = 10, junior jobs = 46.
4. Revisit the junior chart, DevOps role percentages, and the AI insights visual. The underlying skill associations changed, so do not copy their old conclusions unchanged.
5. Label the sample as mixed local, Gulf remote, and other/global listings. Add the collection date range and disclose the convenience-sample limitation.
6. Refresh every visual and export a new screenshot. Replace the original PBIX only after all measures and slicers reconcile with the revised model.

This document describes what can be established from the CSV and SQL. The PBIX was inspected structurally, but its in-app refresh was not available here.
