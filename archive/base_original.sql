-- Creating The DataBase
CREATE TYPE experience_level_enum AS ENUM ('Junior','Mid','Senior');
CREATE TYPE job_type_enum AS ENUM ('Remote','Onsite','Hybrid');
CREATE TYPE origin_type_enum AS ENUM ('Local_Syria','Gulf_Remote','Other');

CREATE TABLE companies (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    origin_type origin_type_enum NOT NULL
);

CREATE TABLE locations (
    id SERIAL PRIMARY KEY,
    city VARCHAR(100),
    country VARCHAR(100) NOT NULL
);

CREATE TABLE job_sources (
    id SERIAL PRIMARY KEY,
    source_name VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE jobs (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    company_id INT REFERENCES companies(id) ON DELETE CASCADE,
    location_id INT REFERENCES locations(id),
    source_id INT REFERENCES job_sources(id),
    experience_level experience_level_enum NOT NULL,
    experience_years_min INT CHECK (experience_years_min >= 0),
    experience_years_max INT CHECK (experience_years_max >= experience_years_min),
    job_type job_type_enum NOT NULL,
    posted_date DATE,
    description TEXT
);

CREATE TABLE skills (
    id SERIAL PRIMARY KEY,
    skill_name VARCHAR(100) NOT NULL UNIQUE,
    category VARCHAR(100)
);

CREATE TABLE job_skills (
    job_id INT REFERENCES jobs(id) ON DELETE CASCADE,
    skill_id INT REFERENCES skills(id) ON DELETE CASCADE,
    PRIMARY KEY (job_id, skill_id)
);

-- STEP 1: Create raw_jobs table
CREATE TABLE raw_jobs (
    job_title TEXT,
    company_name TEXT,
    origin_type TEXT,
    city TEXT,
    country TEXT,
    source TEXT,
    experience_level TEXT,
    experience_years_min INT,
    experience_years_max INT,
    job_type TEXT,
    posted_date DATE,
    salary TEXT,
    skills TEXT,
    description TEXT
);
-- Step 2 importing the data as CSV file to the DataBase

-- STEP 3: Check data
SELECT * FROM raw_jobs LIMIT 10 ;

-- STEP 4: Insert companies
INSERT INTO companies (name, origin_type)
SELECT DISTINCT company_name, origin_type::origin_type_enum
FROM raw_jobs
WHERE company_name IS NOT NULL
ON CONFLICT (name) DO NOTHING;

-- STEP 5: Insert locations
INSERT INTO locations (city, country)
SELECT DISTINCT city, country
FROM raw_jobs;

-- STEP 6: Insert sources
INSERT INTO job_sources (source_name)
SELECT DISTINCT source
FROM raw_jobs;

-- STEP 7: Insert jobs
INSERT INTO jobs (
    title,
    company_id,
    location_id,
    source_id,
    experience_level,
    experience_years_min,
    experience_years_max,
    job_type,
    posted_date,
    description
)
SELECT
    r.job_title,
    c.id,
    l.id,
    s.id,
    r.experience_level::experience_level_enum,
    r.experience_years_min,
    r.experience_years_max,
    r.job_type::job_type_enum,
    r.posted_date,
    r.description
FROM raw_jobs r
LEFT JOIN companies c ON r.company_name = c.name
LEFT JOIN locations l ON r.city = l.city AND r.country = l.country
LEFT JOIN job_sources s ON r.source = s.source_name;

-- STEP 8: Insert skills
INSERT INTO skills (skill_name)
SELECT DISTINCT TRIM(unnest(string_to_array(skills, ',')))
FROM raw_jobs
WHERE skills IS NOT NULL;

-- STEP 9: Insert job_skills
INSERT INTO job_skills (job_id, skill_id)
SELECT
    j.id,
    s.id
FROM raw_jobs r
JOIN jobs j ON j.title = r.job_title
JOIN LATERAL unnest(string_to_array(r.skills, ',')) AS sk(skill_text) ON TRUE
JOIN skills s ON s.skill_name = TRIM(sk.skill_text);
 
-- Step 10: Cleaning the jobs table
ALTER TABLE jobs ADD COLUMN clean_title TEXT;
UPDATE jobs
SET clean_title =
CASE
    -- 1. Full Stack (لازم يكون أول شي)
    WHEN title ILIKE '%full stack%' OR title ILIKE '%full-stack%' THEN 'Full Stack Developer'
    -- 2. AI / ML
    WHEN title ILIKE '%ai%' 
      OR title ILIKE '%artificial intelligence%' 
      OR title ILIKE '%machine learning%' 
      OR title ILIKE '%ml%' 
      OR title ILIKE '%llm%' THEN 'AI Engineer'
    -- 3. Backend
    WHEN title ILIKE '%backend%' 
      OR title ILIKE '%.net%' 
      OR title ILIKE '%laravel%' 
      OR title ILIKE '%node.js%' 
      OR title ILIKE '%php%' 
      OR title ILIKE '%java%' THEN 'Backend Developer'
    -- 4. Frontend
    WHEN title ILIKE '%frontend%' 
      OR title ILIKE '%front-end%' 
      OR title ILIKE '%front end%' 
      OR title ILIKE '%react%' 
      OR title ILIKE '%vue%' 
      OR title ILIKE '%angular%' 
      OR title ILIKE '%next.js%' THEN 'Frontend Developer'
    -- 5. Mobile
    WHEN title ILIKE '%mobile%' 
      OR title ILIKE '%flutter%' 
      OR title ILIKE '%android%' 
      OR title ILIKE '%ios%' 
      OR title ILIKE '%react native%' THEN 'Mobile Developer'
    -- 6. Data
    WHEN title ILIKE '%data analyst%' 
      OR title ILIKE '%data analysis%' THEN 'Data Analyst'
    -- 7. DevOps
    WHEN title ILIKE '%devops%' THEN 'DevOps Engineer'
    -- 8. QA
    WHEN title ILIKE '%qa%' 
      OR title ILIKE '%test%' THEN 'QA Engineer'
    -- 9. Cybersecurity
    WHEN title ILIKE '%cyber%' 
      OR title ILIKE '%security%' THEN 'Cybersecurity'
    -- 10. Cloud
    WHEN title ILIKE '%cloud%' THEN 'Cloud Engineer'
    -- 11. UI/UX
    WHEN title ILIKE '%ui%' 
      OR title ILIKE '%ux%' THEN 'UI/UX Designer'
    -- 12. Software Engineer (عام)
    WHEN title ILIKE '%software engineer%' THEN 'Software Engineer'
    -- 13. Web Developer (بدل ما تروح Other)
    WHEN title ILIKE '%web developer%' THEN 'Frontend Developer'
    -- 14. DevRel
    WHEN title ILIKE '%developer relations%' THEN 'Developer Relations'
    -- 15. SEO / Marketing
    WHEN title ILIKE '%seo%' 
      OR title ILIKE '%marketing%' THEN 'Marketing / SEO'
    -- fallback
    ELSE title
END;

-- Here we cleaned the experience years columns and then checked it, it should return an empty table
UPDATE jobs
SET experience_years_max = experience_years_min
WHERE experience_years_max IS NULL;
SELECT *
FROM jobs
WHERE experience_years_max IS NULL;

-- Categorize jobs into experience ranges for easier analysis and visualization in Power BI
ALTER TABLE jobs
ADD COLUMN experience_range TEXT;

UPDATE jobs
SET experience_range =
CASE
    WHEN experience_years_max <= 1 THEN '0-1 Years'
    WHEN experience_years_max <= 3 THEN '1-3 Years'
    WHEN experience_years_max <= 5 THEN '3-5 Years'
    WHEN experience_years_max <= 8 THEN '5-8 Years'
    ELSE '8+ Years'
END;

-- Extracting the salary form the raw_jobs table to the jobs table and make sure it's identical because there is no id in the raw_jobs table
WITH raw_numbered AS (
    SELECT
        salary,
        ROW_NUMBER() OVER () AS rn
    FROM raw_jobs
),
jobs_numbered AS (
    SELECT
        id,
        ROW_NUMBER() OVER () AS rn
    FROM jobs
)

UPDATE jobs j
SET
    salary_min = CASE
        WHEN r.salary LIKE '%-%'
        THEN SPLIT_PART(TRIM(r.salary), '-', 1)::INTEGER
        ELSE TRIM(r.salary)::INTEGER
    END,

    salary_max = CASE
        WHEN r.salary LIKE '%-%'
        THEN SPLIT_PART(TRIM(r.salary), '-', 2)::INTEGER
        ELSE TRIM(r.salary)::INTEGER
    END
FROM jobs_numbered jn
JOIN raw_numbered r
ON jn.rn = r.rn
WHERE j.id = jn.id
AND r.salary IS NOT NULL;

-- 11 Cleaning the Companies table: 
UPDATE jobs
SET company_id = (
    SELECT id FROM companies
    WHERE name = 'MetaMAS'
    LIMIT 1
)
WHERE company_id = (
    SELECT id FROM companies
    WHERE name = 'METAMAS'
    LIMIT 1
);
DELETE FROM companies
WHERE name = 'METAMAS';

UPDATE jobs
SET company_id = (
    SELECT id FROM companies
    WHERE name = 'MetaGate'
    LIMIT 1
)
WHERE company_id = (
    SELECT id FROM companies
    WHERE name = 'Metagate'
    LIMIT 1
);
DELETE FROM companies
WHERE name = 'Metagate';

UPDATE jobs
SET company_id = 38
WHERE company_id IN (
    SELECT id
    FROM companies
    WHERE name IN ('L-One', 'L-One LLC')
);
DELETE FROM companies
WHERE name IN ('L-One', 'L-One LLC');

-- Merge all ambiguous company jobs into id=18
UPDATE jobs
SET company_id = 18
WHERE company_id IN (
    SELECT id FROM companies
    WHERE name ILIKE '%unknown%'
       OR name ILIKE '%private company%'
       OR name ILIKE '%software company%'
       OR name ILIKE '%company%' AND LENGTH(name) < 15  -- catches vague generic names
);

-- Delete the now-empty ambiguous companies (keep id=18)
DELETE FROM companies
WHERE id != 18
AND (
    name ILIKE '%unknown%'
    OR name ILIKE '%private company%'
    OR name ILIKE '%software company%'
);

-- Rename id=18 to clean canonical value
UPDATE companies
SET name = 'Unknown'
WHERE id = 18;

-- Fix Arabic encoding
UPDATE companies SET name = 'الاتحاد للبلاستيك' WHERE id = 16;
UPDATE companies SET name = 'البراق'             WHERE id = 33;
UPDATE companies SET name = 'كمون'               WHERE id = 90;

-- Verify everything
SELECT 
    c.id, 
    c.name, 
    c.origin_type,
    COUNT(j.id) AS job_count
FROM companies c
LEFT JOIN jobs j ON j.company_id = c.id
GROUP BY c.id, c.name, c.origin_type
ORDER BY c.id;

SELECT 
    clean_title,
    job_type,
    experience_level,
    COUNT(*) AS count
FROM jobs
GROUP BY clean_title, job_type, experience_level
ORDER BY count DESC;
--Step 12: Cleaning the locations table

-- See how many jobs per location
SELECT 
    l.id, 
    l.city, 
    l.country, 
    COUNT(j.id) AS job_count
FROM locations l
LEFT JOIN jobs j ON j.location_id = l.id
GROUP BY l.id, l.city, l.country
ORDER BY l.country, l.city;

-- How many jobs have NULL location_id?
SELECT 
    COUNT(*) AS total_jobs,
    COUNT(location_id) AS jobs_with_location,
    COUNT(*) - COUNT(location_id) AS jobs_without_location
FROM jobs;

-- Break it down by job_type to see if there's a pattern
SELECT 
    job_type,
    COUNT(*) AS total,
    COUNT(location_id) AS has_location,
    COUNT(*) - COUNT(location_id) AS missing_location
FROM jobs
GROUP BY job_type
ORDER BY missing_location DESC;

SELECT 
    j.job_type,
    c.origin_type,
    COUNT(*) AS missing_count
FROM jobs j
JOIN companies c ON j.company_id = c.id
WHERE j.location_id IS  NULL
GROUP BY j.job_type, c.origin_type
ORDER BY j.job_type, c.origin_type;

SELECT DISTINCT
    c.id AS company_id,
    c.name AS company_name,
    c.origin_type,
    j.job_type,
    COUNT(j.id) AS null_location_jobs
FROM jobs j
JOIN companies c ON j.company_id = c.id
WHERE j.location_id IS NULL
AND j.job_type IN ('Onsite', 'Hybrid','Remote')
AND c.origin_type = 'Local_Syria'
GROUP BY c.id, c.name, c.origin_type, j.job_type
ORDER BY c.name;


SELECT 
    c.name,
    j.title,
    j.job_type,
    j.description
FROM jobs j
JOIN companies c ON j.company_id = c.id
WHERE j.location_id IS NULL
AND c.name IN ('Noon', 'البراق', 'Domis', 'Tradinos', 'L-One L.L.C', 'Ligadata')
ORDER BY c.name;


SELECT 
    c.name AS company,
    l.city,
    l.country,
    COUNT(j.id) AS job_count
FROM jobs j
JOIN companies c ON j.company_id = c.id
JOIN locations l ON j.location_id = l.id
WHERE c.name IN ('BEEORDER', 'Beetronix', 'Paymera', 'Rehabitaire')
GROUP BY c.name, l.city, l.country
ORDER BY c.name;

SELECT 
	
	DISTINCT  c.name AS company,
	j.description
FROM jobs j 
JOIN companies c ON j.company_id=c.id
WHERE c.name IN ('BEEORDER', 'Beetronix', 'Paymera', 'Rehabitaire')


-- Check Remote + Other companies
SELECT 
    c.name AS company,
    c.origin_type,
    j.job_type,
    j.title,
    j.description
FROM jobs j
JOIN companies c ON j.company_id = c.id
WHERE j.job_type = 'Remote'
AND c.origin_type = 'Other'
AND j.location_id IS NULL
ORDER BY c.name;

-- Check Onsite + Other companies
SELECT 
    c.name AS company,
    c.origin_type,
    j.job_type,
    j.title,
    j.description
FROM jobs j
JOIN companies c ON j.company_id = c.id
WHERE j.job_type = 'Onsite'
AND c.origin_type = 'Other'
AND j.location_id IS NULL
ORDER BY c.name;

SELECT 
	j.location_id AS location,
	j.job_type AS type,
	c.origin_type AS country,
	c.name AS company_name,
	l.city,
	j.description AS desc

FROM
	jobs j
LEFT JOIN companies c ON j.company_id=c.id
LEFT JOIN locations l ON j.location_id=l.id
WHERE
	c.name='Rehabitaire'
	
-- ============================================
-- STEP 1: Add 'Unverified' to locations table
-- ============================================
INSERT INTO locations (city, country)
VALUES (NULL, 'Unverified');

-- Check what id it got assigned
SELECT id, city, country 
FROM locations 
WHERE country = 'Unverified';

-- ============================================
-- STEP 2: Remote + Local_Syria → Syria (id=13)
-- ============================================
UPDATE jobs j
SET location_id = 13
FROM companies c
WHERE j.company_id = c.id
AND j.job_type = 'Remote'
AND c.origin_type = 'Local_Syria'
AND j.location_id IS NULL;

-- ============================================
-- STEP 3: Remote + Gulf_Remote → Gulf (id=17)
-- ============================================
UPDATE jobs j
SET location_id = 17
FROM companies c
WHERE j.company_id = c.id
AND j.job_type = 'Remote'
AND c.origin_type = 'Gulf_Remote'
AND j.location_id IS NULL;

-- ============================================
-- STEP 4: Remote + Other → Unverified 
-- ============================================
UPDATE jobs j
SET location_id = 20  -- replaced with id from STEP 1
FROM companies c
WHERE j.company_id = c.id
AND j.job_type = 'Remote'
AND c.origin_type = 'Other'
AND j.location_id IS NULL;

-- ============================================
-- STEP 5: BEEORDER Onsite → Damascus (id=15)
-- ============================================
UPDATE jobs j
SET location_id = 15
FROM companies c
WHERE j.company_id = c.id
AND c.name = 'BEEORDER'
AND j.location_id IS NULL;

-- ============================================
-- STEP 6: Rehabitaire → Aleppo (id=14)
-- ============================================
UPDATE jobs j
SET location_id = 14
FROM companies c
WHERE j.company_id = c.id
AND c.name = 'Rehabitaire'
AND j.location_id IS NULL;

-- ============================================
-- STEP 7: Remaining Onsite/Hybrid + Local_Syria 
--         → Syria (id=13)
-- ============================================
UPDATE jobs j
SET location_id = 13
FROM companies c
WHERE j.company_id = c.id
AND j.job_type IN ('Onsite', 'Hybrid')
AND c.origin_type = 'Local_Syria'
AND j.location_id IS NULL;

-- ============================================
-- STEP 8: Onsite + Other → NULL (leave as is)
-- ============================================

-- ============================================
-- VERIFY: Check final state
-- ============================================
SELECT 
    j.job_type,
    c.origin_type,
    l.country AS assigned_location,
    COUNT(*) AS total,
    COUNT(j.location_id) AS has_location,
    COUNT(*) - COUNT(j.location_id) AS still_null
FROM jobs j
JOIN companies c ON j.company_id = c.id
LEFT JOIN locations l ON j.location_id = l.id
GROUP BY j.job_type, c.origin_type, l.country
ORDER BY j.job_type, c.origin_type;

-- Confirm these are ALL from Unknown company
SELECT 
    c.name AS company,
    c.origin_type,
    j.job_type,
    l.city,
    l.country,
    COUNT(*) AS job_count
FROM jobs j
JOIN companies c ON j.company_id = c.id
JOIN locations l ON j.location_id = l.id
WHERE c.origin_type = 'Local_Syria'
AND l.country NOT IN ('Syria')
GROUP BY c.name, c.origin_type, j.job_type, l.city, l.country
ORDER BY l.country;

--step 13: Cleaning the skills table

-- Check direct duplicates we identified earlier
SELECT id, skill_name, category
FROM skills
WHERE skill_name IN (
    'React.js', 'React',
    'Express', 'Express.js',
    'Bloc', 'BLoC',
    'Scrum', 'SCRUM',
    'LLM', 'LLMs',
    'Android', 'Android Development',
    'iOS', 'iOS Development',
    'Wireframes', 'Wireframing',
    'Eloquent', 'Eloquent ORM'
)
ORDER BY skill_name;

-- Also check how many jobs use each duplicate
SELECT 
    s.skill_name,
    COUNT(js.job_id) AS used_in_jobs
FROM skills s 
LEFT JOIN job_skills js ON js.skill_id = s.id
WHERE s.skill_name IN (
    'React.js', 'React',
    'Express', 'Express.js',
    'Bloc', 'BLoC',
    'Scrum', 'SCRUM',
    'LLM', 'LLMs',
    'Android', 'Android Development',
    'iOS', 'iOS Development',
    'Wireframes', 'Wireframing',
    'Eloquent', 'Eloquent ORM'
)
GROUP BY s.skill_name
ORDER BY s.skill_name;

-- ===========================
-- Individual counts for duplicates
SELECT 
    s.skill_name,
    COUNT(js.job_id) AS used_in_jobs
FROM skills s
LEFT JOIN job_skills js ON js.skill_id = s.id
GROUP BY s.skill_name
ORDER BY used_in_jobs DESC;

-- Total jobs using ANY of these duplicate skills
SELECT COUNT(DISTINCT js.job_id) AS jobs_affected_by_duplicates
FROM job_skills js
JOIN skills s ON js.skill_id = s.id
WHERE s.skill_name IN (
    'React.js', 'React',
    'Express', 'Express.js',
    'Bloc', 'BLoC',
    'Scrum', 'SCRUM',
    'LLM', 'LLMs',
    'Android', 'Android Development',
    'iOS', 'iOS Development',
    'Wireframes', 'Wireframing',
    'Eloquent', 'Eloquent ORM'
);

-- Total jobs in database for comparison
SELECT COUNT(*) AS total_jobs FROM jobs;

-- ===================================

-- 1. Find ALL potential duplicates (case insensitive)
SELECT 
    LOWER(skill_name) AS normalized,
    COUNT(*) AS count,
    STRING_AGG(skill_name, ' | ' ORDER BY skill_name) AS variations,
    STRING_AGG(id::TEXT, ' | ' ORDER BY skill_name) AS ids
FROM skills
GROUP BY LOWER(skill_name)
HAVING COUNT(*) > 1
ORDER BY count DESC;

-- 2. Find skills with 0 jobs linked (orphaned skills)
SELECT 
    s.id,
    s.skill_name
FROM skills s
LEFT JOIN job_skills js ON js.skill_id = s.id
WHERE js.job_id IS NULL
ORDER BY s.skill_name;

-- Check jobs using BLoC/Bloc
SELECT 
    j.title,
    j.description,
    s.skill_name
FROM jobs j
JOIN job_skills js ON js.job_id = j.id
JOIN skills s ON js.skill_id = s.id
WHERE s.skill_name IN ('BLoC', 'Bloc')
ORDER BY s.skill_name;

-- Check jobs using Scrum/SCRUM
SELECT 
    j.title,
    j.description,
    s.skill_name
FROM jobs j
JOIN job_skills js ON js.job_id = j.id
JOIN skills s ON js.skill_id = s.id
WHERE s.skill_name IN ('Scrum', 'SCRUM')
ORDER BY s.skill_name;

-- Check jobs using Wireframing/Wireframes
SELECT 
    j.title,
    j.description,
    s.skill_name
FROM jobs j
JOIN job_skills js ON js.job_id = j.id
JOIN skills s ON js.skill_id = s.id
WHERE s.skill_name IN ('Wireframing', 'Wireframes')
ORDER BY s.skill_name;

-- Check jobs using Eloquent/Eloquent ORM
SELECT 
    j.title,
    j.description,
    s.skill_name
FROM jobs j
JOIN job_skills js ON js.job_id = j.id
JOIN skills s ON js.skill_id = s.id
WHERE s.skill_name IN ('Eloquent', 'Eloquent ORM')
ORDER BY s.skill_name;

-- Check jobs that have BOTH Wireframes AND Wireframing simultaneously
SELECT 
    j.id,
    j.title
FROM jobs j
JOIN job_skills js1 ON js1.job_id = j.id
JOIN skills s1 ON js1.skill_id = s1.id AND s1.skill_name = 'Wireframes'
JOIN job_skills js2 ON js2.job_id = j.id
JOIN skills s2 ON js2.skill_id = s2.id AND s2.skill_name = 'Wireframing'
ORDER BY j.id;

-- Same check for BLoC/Bloc
SELECT 
    j.id,
    j.title
FROM jobs j
JOIN job_skills js1 ON js1.job_id = j.id
JOIN skills s1 ON js1.skill_id = s1.id AND s1.skill_name = 'Bloc'
JOIN job_skills js2 ON js2.job_id = j.id
JOIN skills s2 ON js2.skill_id = s2.id AND s2.skill_name = 'BLoC'
ORDER BY j.id;

-- Same check for Scrum/SCRUM
SELECT 
    j.id,
    j.title
FROM jobs j
JOIN job_skills js1 ON js1.job_id = j.id
JOIN skills s1 ON js1.skill_id = s1.id AND s1.skill_name = 'Scrum'
JOIN job_skills js2 ON js2.job_id = j.id
JOIN skills s2 ON js2.skill_id = s2.id AND s2.skill_name = 'SCRUM'
ORDER BY j.id;


-- ============================================
-- STEP 1: Handle overlapping jobs first
-- (jobs that have BOTH versions of the skill)
-- ============================================

-- Wireframes/Wireframing overlaps → delete Wireframes links
-- from jobs that already have Wireframing
DELETE FROM job_skills
WHERE skill_id = (SELECT id FROM skills WHERE skill_name = 'Wireframes')
AND job_id IN (
    SELECT js1.job_id
    FROM job_skills js1
    JOIN job_skills js2 ON js1.job_id = js2.job_id
    WHERE js1.skill_id = (SELECT id FROM skills WHERE skill_name = 'Wireframes')
    AND js2.skill_id = (SELECT id FROM skills WHERE skill_name = 'Wireframing')
);

-- Bloc/BLoC overlaps → delete Bloc links
-- from jobs that already have BLoC
DELETE FROM job_skills
WHERE skill_id = (SELECT id FROM skills WHERE skill_name = 'Bloc')
AND job_id IN (
    SELECT js1.job_id
    FROM job_skills js1
    JOIN job_skills js2 ON js1.job_id = js2.job_id
    WHERE js1.skill_id = (SELECT id FROM skills WHERE skill_name = 'Bloc')
    AND js2.skill_id = (SELECT id FROM skills WHERE skill_name = 'BLoC')
);

-- ============================================
-- STEP 2: Redirect remaining job_skills rows
-- to the keeper skill
-- ============================================

-- React.js → React
UPDATE job_skills
SET skill_id = (SELECT id FROM skills WHERE skill_name = 'React')
WHERE skill_id = (SELECT id FROM skills WHERE skill_name = 'React.js');

-- Express → Express.js
UPDATE job_skills
SET skill_id = (SELECT id FROM skills WHERE skill_name = 'Express.js')
WHERE skill_id = (SELECT id FROM skills WHERE skill_name = 'Express');

-- SCRUM → Scrum
UPDATE job_skills
SET skill_id = (SELECT id FROM skills WHERE skill_name = 'Scrum')
WHERE skill_id = (SELECT id FROM skills WHERE skill_name = 'SCRUM');

-- Bloc → BLoC (remaining non-overlapping jobs)
UPDATE job_skills
SET skill_id = (SELECT id FROM skills WHERE skill_name = 'BLoC')
WHERE skill_id = (SELECT id FROM skills WHERE skill_name = 'Bloc');

-- LLMs → LLM
UPDATE job_skills
SET skill_id = (SELECT id FROM skills WHERE skill_name = 'LLM')
WHERE skill_id = (SELECT id FROM skills WHERE skill_name = 'LLMs');

-- Android Development → Android
UPDATE job_skills
SET skill_id = (SELECT id FROM skills WHERE skill_name = 'Android')
WHERE skill_id = (SELECT id FROM skills WHERE skill_name = 'Android Development');

-- iOS Development → iOS
UPDATE job_skills
SET skill_id = (SELECT id FROM skills WHERE skill_name = 'iOS')
WHERE skill_id = (SELECT id FROM skills WHERE skill_name = 'iOS Development');

-- Wireframes → Wireframing (remaining non-overlapping jobs)
UPDATE job_skills
SET skill_id = (SELECT id FROM skills WHERE skill_name = 'Wireframing')
WHERE skill_id = (SELECT id FROM skills WHERE skill_name = 'Wireframes');

-- Eloquent → Eloquent ORM
UPDATE job_skills
SET skill_id = (SELECT id FROM skills WHERE skill_name = 'Eloquent ORM')
WHERE skill_id = (SELECT id FROM skills WHERE skill_name = 'Eloquent');

-- ============================================
-- STEP 3: Delete the duplicate skills
-- from the skills table
-- ============================================
DELETE FROM skills
WHERE skill_name IN (
    'React.js',
    'Express',
    'SCRUM',
    'Bloc',
    'LLMs',
    'Android Development',
    'iOS Development',
    'Wireframes',
    'Eloquent'
);

-- ============================================
-- VERIFY: Check duplicates are gone
-- ============================================
SELECT 
    LOWER(skill_name) AS normalized,
    COUNT(*) AS count,
    STRING_AGG(skill_name, ' | ') AS variations
FROM skills
GROUP BY LOWER(skill_name)
HAVING COUNT(*) > 1;

-- Check total skills before and after
SELECT COUNT(*) AS total_skills FROM skills;

-- Make sure no orphaned skills
SELECT COUNT(*) AS orphaned_skills
FROM skills s
LEFT JOIN job_skills js ON js.skill_id = s.id
WHERE js.job_id IS NULL;

-- Check ALL pairs for overlapping jobs
SELECT 'React/React.js' AS pair, j.id, j.title
FROM jobs j
JOIN job_skills js1 ON js1.job_id = j.id
JOIN skills s1 ON js1.skill_id = s1.id AND s1.skill_name = 'React'
JOIN job_skills js2 ON js2.job_id = j.id
JOIN skills s2 ON js2.skill_id = s2.id AND s2.skill_name = 'React.js'

UNION ALL

SELECT 'Express/Express.js', j.id, j.title
FROM jobs j
JOIN job_skills js1 ON js1.job_id = j.id
JOIN skills s1 ON js1.skill_id = s1.id AND s1.skill_name = 'Express'
JOIN job_skills js2 ON js2.job_id = j.id
JOIN skills s2 ON js2.skill_id = s2.id AND s2.skill_name = 'Express.js'

UNION ALL

SELECT 'Scrum/SCRUM', j.id, j.title
FROM jobs j
JOIN job_skills js1 ON js1.job_id = j.id
JOIN skills s1 ON js1.skill_id = s1.id AND s1.skill_name = 'Scrum'
JOIN job_skills js2 ON js2.job_id = j.id
JOIN skills s2 ON js2.skill_id = s2.id AND s2.skill_name = 'SCRUM'

UNION ALL

SELECT 'LLM/LLMs', j.id, j.title
FROM jobs j
JOIN job_skills js1 ON js1.job_id = j.id
JOIN skills s1 ON js1.skill_id = s1.id AND s1.skill_name = 'LLM'
JOIN job_skills js2 ON js2.job_id = j.id
JOIN skills s2 ON js2.skill_id = s2.id AND s2.skill_name = 'LLMs'

UNION ALL

SELECT 'Android/Android Development', j.id, j.title
FROM jobs j
JOIN job_skills js1 ON js1.job_id = j.id
JOIN skills s1 ON js1.skill_id = s1.id AND s1.skill_name = 'Android'
JOIN job_skills js2 ON js2.job_id = j.id
JOIN skills s2 ON js2.skill_id = s2.id AND s2.skill_name = 'Android Development'

UNION ALL

SELECT 'iOS/iOS Development', j.id, j.title
FROM jobs j
JOIN job_skills js1 ON js1.job_id = j.id
JOIN skills s1 ON js1.skill_id = s1.id AND s1.skill_name = 'iOS'
JOIN job_skills js2 ON js2.job_id = j.id
JOIN skills s2 ON js2.skill_id = s2.id AND s2.skill_name = 'iOS Development'

UNION ALL

SELECT 'Eloquent/Eloquent ORM', j.id, j.title
FROM jobs j
JOIN job_skills js1 ON js1.job_id = j.id
JOIN skills s1 ON js1.skill_id = s1.id AND s1.skill_name = 'Eloquent'
JOIN job_skills js2 ON js2.job_id = j.id
JOIN skills s2 ON js2.skill_id = s2.id AND s2.skill_name = 'Eloquent ORM'

ORDER BY pair, id;

-- ============================================
-- STEP 1: DELETE overlaps first
-- ============================================

-- React/React.js overlaps
DELETE FROM job_skills
WHERE skill_id = (SELECT id FROM skills WHERE skill_name = 'React.js')
AND job_id IN (
    SELECT js1.job_id FROM job_skills js1
    JOIN job_skills js2 ON js1.job_id = js2.job_id
    WHERE js1.skill_id = (SELECT id FROM skills WHERE skill_name = 'React.js')
    AND js2.skill_id = (SELECT id FROM skills WHERE skill_name = 'React')
);

-- Express/Express.js overlaps
DELETE FROM job_skills
WHERE skill_id = (SELECT id FROM skills WHERE skill_name = 'Express')
AND job_id IN (
    SELECT js1.job_id FROM job_skills js1
    JOIN job_skills js2 ON js1.job_id = js2.job_id
    WHERE js1.skill_id = (SELECT id FROM skills WHERE skill_name = 'Express')
    AND js2.skill_id = (SELECT id FROM skills WHERE skill_name = 'Express.js')
);

-- LLM/LLMs overlaps
DELETE FROM job_skills
WHERE skill_id = (SELECT id FROM skills WHERE skill_name = 'LLMs')
AND job_id IN (
    SELECT js1.job_id FROM job_skills js1
    JOIN job_skills js2 ON js1.job_id = js2.job_id
    WHERE js1.skill_id = (SELECT id FROM skills WHERE skill_name = 'LLMs')
    AND js2.skill_id = (SELECT id FROM skills WHERE skill_name = 'LLM')
);

-- ============================================
-- STEP 2: MERGE remaining rows
-- ============================================

-- React.js → React
UPDATE job_skills
SET skill_id = (SELECT id FROM skills WHERE skill_name = 'React')
WHERE skill_id = (SELECT id FROM skills WHERE skill_name = 'React.js');

-- Express → Express.js
UPDATE job_skills
SET skill_id = (SELECT id FROM skills WHERE skill_name = 'Express.js')
WHERE skill_id = (SELECT id FROM skills WHERE skill_name = 'Express');

-- SCRUM → Scrum
UPDATE job_skills
SET skill_id = (SELECT id FROM skills WHERE skill_name = 'Scrum')
WHERE skill_id = (SELECT id FROM skills WHERE skill_name = 'SCRUM');

-- LLMs → LLM
UPDATE job_skills
SET skill_id = (SELECT id FROM skills WHERE skill_name = 'LLM')
WHERE skill_id = (SELECT id FROM skills WHERE skill_name = 'LLMs');

-- Android Development → Android
UPDATE job_skills
SET skill_id = (SELECT id FROM skills WHERE skill_name = 'Android')
WHERE skill_id = (SELECT id FROM skills WHERE skill_name = 'Android Development');

-- iOS Development → iOS
UPDATE job_skills
SET skill_id = (SELECT id FROM skills WHERE skill_name = 'iOS')
WHERE skill_id = (SELECT id FROM skills WHERE skill_name = 'iOS Development');

-- Eloquent → Eloquent ORM
UPDATE job_skills
SET skill_id = (SELECT id FROM skills WHERE skill_name = 'Eloquent ORM')
WHERE skill_id = (SELECT id FROM skills WHERE skill_name = 'Eloquent');

-- ============================================
-- STEP 3: DELETE duplicate skills from skills table
-- ============================================
DELETE FROM skills
WHERE skill_name IN (
    'React.js',
    'Express',
    'SCRUM',
    'Bloc',
    'LLMs',
    'Android Development',
    'iOS Development',
    'Wireframes',
    'Eloquent'
);

-- ============================================
-- VERIFY
-- ============================================
-- 1. Confirm no more duplicates
SELECT 
    LOWER(skill_name) AS normalized,
    COUNT(*) AS count,
    STRING_AGG(skill_name, ' | ') AS variations
FROM skills
GROUP BY LOWER(skill_name)
HAVING COUNT(*) > 1;

-- 2. Confirm no orphaned skills
SELECT COUNT(*) AS orphaned
FROM skills s
LEFT JOIN job_skills js ON js.skill_id = s.id
WHERE js.job_id IS NULL;

-- 3. New total skill count
SELECT COUNT(*) AS total_skills FROM skills;


-- Preview: how many skills per category would we get?
SELECT category, COUNT(*) 
FROM skills 
GROUP BY category;
-- Currently returns: NULL | 292


-- ============================================
-- Frontend
-- ============================================
UPDATE skills SET category = 'Frontend'
WHERE skill_name IN (
    'HTML', 'HTML5', 'CSS', 'CSS3', 'SCSS',
    'JavaScript', 'TypeScript',
    'React', 'React Native', 'React Query',
    'Redux', 'Redux Toolkit', 'Zustand',
    'Vue.js', 'Angular', 'Angular Material',
    'Next.js', 'Vite', 'Webpack',
    'Bootstrap', 'Tailwind CSS', 'Material UI',
    'Responsive Design', 'Web Design',
    'SPA', 'SSR', 'SSG', 'ISR',
    'Virtual DOM', 'Axios',
    'Figma', 'Adobe XD',
    'UI Design', 'UI/UX',
    'User Interface', 'User Experience',
    'User Research', 'UX Research',
    'Wireframing', 'Prototyping',
    'Design Systems', 'Mobile Design',
    'Usability', 'User Flows',
    'Animation', 'Web Scraping',
    'Material Design', 'Blazor', 'WPF'
);

-- ============================================
-- Backend
-- ============================================
UPDATE skills SET category = 'Backend'
WHERE skill_name IN (
    'Node.js', 'Express.js', 'NestJS',
    'PHP', 'Laravel', 'Symfony',
    'FilamentPHP', 'PHPUnit', 'Pest',
    'Python', 'Django', 'Django REST', 'FastAPI',
    'Java', 'Spring Boot',
    'C#', '.NET', '.NET Core', '.NET 6/7/8', '.NET Integration',
    'ASP.NET Core', 'Entity Framework', 'EF Core',
    'SignalR', 'gRPC', 'REST API',
    'GraphQL', 'WebSockets', 'Socket.io',
    'Microservices', 'MVC', 'SOLID', 'OOP',
    'Clean Architecture', 'Clean Code',
    'Design Patterns', 'Domain Driven Design',
    'Backend Architecture', 'Backend Development',
    'Dependency Injection', 'Eloquent ORM',
    'Doctrine ORM', 'TypeORM', 'Prisma', 'Sequelize',
    'APIs', 'API Integration', 'API Security',
    'Authentication', 'OAuth', 'JWT',
    'Webhooks', 'Swagger', 'Postman',
    'MVI', 'MVVM', 'VIPER',
    'Go', 'R', 'Bash', 'Scripting',
    'Windows Services', 'Windows Server',
    'SaaS', 'SaaS Architecture',
    'CMS', 'ERP Integration', 'CRM Integration',
    'JSON', 'Architecture Design',
    'Backend Architecture', 'Channels'
);

-- ============================================
-- Mobile
-- ============================================
UPDATE skills SET category = 'Mobile'
WHERE skill_name IN (
    'Flutter', 'Dart',
    'React Native',
    'Android', 'Android SDK', 'Android Development',
    'Kotlin', 'Java',
    'iOS', 'iOS SDK', 'iOS Development',
    'Swift', 'SwiftUI', 'UIKit',
    'Jetpack', 'Jetpack Compose', 'Hilt',
    'Room', 'Retrofit',
    'BLoC', 'Cubit', 'Provider', 'Riverpod',
    'State Management',
    'Firebase',
    'Core Data', 'Combine', 'URLSession',
    'Navigation', 'Mobile Development',
    'Mobile UI Development',
    'Google Play Publishing',
    'Android SDK'
);

-- ============================================
-- DevOps & Cloud
-- ============================================
UPDATE skills SET category = 'DevOps & Cloud'
WHERE skill_name IN (
    'Docker', 'Kubernetes', 'Terraform',
    'CI/CD', 'Jenkins', 'GitOps',
    'ArgoCD', 'FluxCD', 'Istio',
    'Prometheus', 'Grafana', 'Monitoring',
    'AWS', 'Azure', 'GCP',
    'Azure DevOps',
    'Cloud', 'Cloud Native', 'Cloud Engineering',
    'Cloud Infrastructure', 'Cloud Security',
    'Infrastructure', 'Infrastructure Management',
    'DevOps', 'Linux', 'Bash',
    'Virtualization', 'Kubeflow',
    'MLflow', 'RPA', 'Automation',
    'n8n', 'Zapier', 'UiPath'
);

-- ============================================
-- Data & AI
-- ============================================
UPDATE skills SET category = 'Data & AI'
WHERE skill_name IN (
    'Python', 'R',
    'Machine Learning', 'ML Models',
    'TensorFlow', 'PyTorch', 'Keras',
    'Scikit-learn', 'Hugging Face',
    'LLM', 'LLM APIs', 'LangChain',
    'RAG', 'Fine-tuning', 'Prompt Engineering',
    'NLP', 'Computer Vision',
    'AI', 'AI/ML', 'AI Concepts',
    'AI Integration', 'AI Systems', 'AI APIs',
    'GPT', 'OpenAI',
    'Voice AI', 'STT', 'TTS',
    'DSP', 'Audio Processing',
    'Emotion Recognition',
    'Model Deployment', 'Model Evaluation',
    'Vector Databases', 'Big Data',
    'Data Analysis', 'Data Modeling',
    'Data Classification', 'Data Storage',
    'Statistics', 'Sales Analysis',
    'SQL', 'NoSQL',
    'Power BI', 'Tableau',
    'Excel', 'Microsoft Office',
    'Analytics Tools', 'Reporting',
    'Machine Learning Projects'
);

-- ============================================
-- Databases
-- ============================================
UPDATE skills SET category = 'Databases'
WHERE skill_name IN (
    'MySQL', 'PostgreSQL', 'MongoDB',
    'Redis', 'SQLite', 'Oracle',
    'MS SQL Server', 'SQL Server',
    'Elasticsearch', 'Sybase',
    'RabbitMQ', 'NATS',
    'Firebase'
);

-- ============================================
-- Security
-- ============================================
UPDATE skills SET category = 'Security'
WHERE skill_name IN (
    'Cybersecurity', 'Cyber Security',
    'Penetration Testing', 'OWASP',
    'Burp Suite', 'Nmap',
    'Firewalls', 'IDS/IPS', 'WAF',
    'VPN', 'Encryption',
    'Security', 'Security Best Practices',
    'Security Frameworks', 'API Security',
    'Cloud Security', 'Vulnerability Management',
    'SIEM', 'SOC',
    'Active Directory', 'Group Policy',
    'Windows Server', 'DNS', 'DHCP',
    'Networking', 'LAN', 'WAN', 'WLAN',
    'Switches', 'Routers',
    'Data Classification'
);

-- ============================================
-- Soft Skills & Tools
-- ============================================
UPDATE skills SET category = 'Tools & Practices'
WHERE skill_name IN (
    'Git', 'GitHub', 'GitLab',
    'Jira', 'Postman', 'Swagger',
    'Agile', 'Scrum', 'Kanban', 'TDD', 'TDD',
    'Testing', 'QA', 'Selenium',
    'Jest', 'Cypress', 'Debugging',
    'Performance Optimization',
    'Socket Programming',
    'MERN Stack',
    'Communication', 'Training',
    'IoT', 'Stripe',
    'SEO', 'SaaS',
    'Dependency Injection'
);

-- ============================================
-- VERIFY
-- ============================================
-- 1. Check category distribution
SELECT 
    category,
    COUNT(*) AS skill_count
FROM skills
GROUP BY category
ORDER BY skill_count DESC;

-- 2. Check how many still have NULL category
SELECT COUNT(*) AS still_null
FROM skills
WHERE category IS NULL;

-- 3. Show remaining NULL skills so we can fix them
SELECT id, skill_name
FROM skills
WHERE category IS NULL
ORDER BY skill_name;

SELECT * FROM skills


UPDATE skills SET category = 'Backend'
WHERE skill_name = 'C++';

UPDATE skills SET category = 'Databases'
WHERE skill_name = 'Databases';



-- Where is Firebase actually used?
SELECT j.clean_title, COUNT(*) AS count
FROM jobs j
JOIN job_skills js ON js.job_id = j.id
JOIN skills s ON js.skill_id = s.id
WHERE s.skill_name = 'Firebase'
GROUP BY j.clean_title
ORDER BY count DESC;

-- Where is Java actually used?
SELECT j.clean_title, COUNT(*) AS count
FROM jobs j
JOIN job_skills js ON js.job_id = j.id
JOIN skills s ON js.skill_id = s.id
WHERE s.skill_name = 'Java'
GROUP BY j.clean_title
ORDER BY count DESC;


-- Why does Java appear in DevOps jobs?
SELECT 
    j.title,
    j.description
FROM jobs j
JOIN job_skills js ON js.job_id = j.id
JOIN skills s ON js.skill_id = s.id
WHERE s.skill_name = 'Java'
AND j.clean_title = 'DevOps Engineer'
LIMIT 3;

UPDATE skills 
SET category = 'Mobile' 
WHERE skill_name IN ('MVVM', 'MVI', 'VIPER');

UPDATE skills 
SET category = 'Data & AI' 
WHERE skill_name = 'Web Scraping';

-- Last step: Last check on the data after clening 

SELECT 
    COUNT(*) AS total_jobs,
    SUM(CASE WHEN clean_title IS NULL THEN 1 ELSE 0 END) AS missing_clean_titles,
    SUM(CASE WHEN location_id IS NULL THEN 1 ELSE 0 END) AS missing_locations,
    SUM(CASE WHEN experience_range IS NULL THEN 1 ELSE 0 END) AS missing_experience_ranges,
    SUM(CASE WHEN job_type IS NULL THEN 1 ELSE 0 END) AS missing_job_types
FROM jobs;

SELECT id, title, salary_min, salary_max
FROM jobs
WHERE salary_min > salary_max;


SELECT id, clean_title, experience_years_min, experience_years_max
FROM jobs
WHERE experience_years_min > experience_years_max;


SELECT s.id, s.skill_name 
FROM skills s
LEFT JOIN job_skills js ON s.id = js.skill_id
WHERE js.job_id IS NULL;

SELECT c.id, c.name 
FROM companies c
LEFT JOIN jobs j ON c.id = j.company_id
WHERE j.id IS NULL;

SELECT 
    category, 
    COUNT(*) AS skills_count
FROM skills
GROUP BY category
ORDER BY skills_count DESC;

SELECT * FROM skills WHERE category IS NULL;

SELECT 
    title, 
    company_id, 
    posted_date, 
    COUNT(*) AS duplicates_count
FROM jobs
GROUP BY title, company_id, posted_date
HAVING COUNT(*) > 1;


SELECT 
    title, 
    company_id, 
    posted_date, 
    job_type,
    location_id,
    COUNT(*) AS duplicates_count
FROM jobs
GROUP BY 
    title, 
    company_id, 
    posted_date, 
    job_type, 
    location_id, 
    description
HAVING COUNT(*) > 1;

SELECT DISTINCT clean_title,experience_level,experience_range FROM jobs


SELECT 
    j.clean_title, 
    c.name AS company_name, 
    COUNT(js.skill_id) AS total_skills_required
FROM jobs j
JOIN job_skills js ON j.id = js.job_id
JOIN companies c ON j.company_id = c.id
GROUP BY j.id, j.clean_title, c.name
ORDER BY total_skills_required DESC
LIMIT 5;
------------------------
WITH ranked_jobs AS (
    SELECT 
		j.id,
        j.clean_title AS job_title,
        c.name AS company_name,
        COUNT(js.skill_id) AS skill_count,
        ROW_NUMBER() OVER (
            PARTITION BY j.clean_title 
            ORDER BY COUNT(js.skill_id) DESC
        ) AS rn
    FROM jobs j
    LEFT JOIN companies c ON c.id = j.company_id
    LEFT JOIN job_skills js ON js.job_id = j.id
    WHERE c.name != 'Unknown'
    GROUP BY j.id, j.clean_title, c.name
)
SELECT 
	id,
    job_title,
    company_name,
    skill_count
FROM ranked_jobs
WHERE rn = 1
ORDER BY skill_count DESC
LIMIT 5;

-- SELECT 
--     j.id AS job_id,
--     j.clean_title,
-- 	r.job_title,
--     r.skills AS raw_skills_text, -- النص الخام للمهارات قبل التنظيف
--     STRING_AGG(s.skill_name, ', ' ORDER BY s.skill_name) AS parsed_skills_list
-- FROM jobs j
-- JOIN raw_jobs r ON j.title = r.job_title -- أو عبر المفتاح الذي ربطت به الجدولين
-- JOIN job_skills js ON j.id = js.job_id
-- JOIN skills s ON js.skill_id = s.id
-- WHERE j.id = 65 -- استبدل 123 بـ id الوظيفة المطلوب فحصها
-- GROUP BY j.id, j.clean_title, r.skills,r.job_title;

-- SELECT job_title, COUNT(*) 
-- FROM raw_jobs 
-- WHERE job_title = (SELECT title FROM jobs WHERE id = 65)
-- GROUP BY job_title;


-- SELECT j.id, j.title, r.skills 
-- FROM jobs j
-- JOIN raw_jobs r ON j.title = r.job_title
-- WHERE j.id = 65;

-- SELECT COUNT(DISTINCT skill_id) 
-- FROM job_skills 
-- WHERE job_id = 65;

-- SELECT 
--     company_name, 
--     COUNT(*) AS total_postings
-- FROM raw_jobs 
-- WHERE job_title = (SELECT title FROM jobs WHERE id = 65)
-- GROUP BY company_name;

-- SELECT 

--     company_name, 
--     job_title, 
-- 	posted_date,
--     skills AS raw_skills
-- FROM raw_jobs 
-- WHERE job_title = (SELECT title FROM jobs WHERE id = 65);


SELECT 
    j.clean_title,
    COUNT(DISTINCT r.company_name) AS total_companies,
    COUNT(DISTINCT r.posted_date) AS total_postings_count,
    COUNT(DISTINCT js.skill_id) AS total_unique_skills,
    MIN(r.posted_date) AS earliest_posting,
    MAX(r.posted_date) AS latest_posting,
    STRING_AGG(DISTINCT s.skill_name, ', ' ORDER BY s.skill_name) AS full_market_skills
FROM jobs j
JOIN raw_jobs r ON j.title = r.job_title
JOIN job_skills js ON j.id = js.job_id
JOIN skills s ON js.skill_id = s.id
WHERE r.company_name != 'Unknown'
GROUP BY j.clean_title
ORDER BY total_unique_skills DESC
LIMIT 10;
------------------------------------
SELECT 
    j.clean_title, 
    s.skill_name, 
    s.category AS skill_category,
    COUNT(*) as times_requested
FROM jobs j
JOIN job_skills js ON j.id = js.job_id
JOIN skills s ON js.skill_id = s.id
-- هنا نبحث عن وظائف الفرونت إند التي تطلب مهارات باك إند أو العكس
WHERE j.clean_title LIKE '%Frontend%' AND s.category = 'Backend'
GROUP BY j.clean_title, s.skill_name, s.category
ORDER BY times_requested DESC
LIMIT 10;


SELECT 
    s.skill_name, 
    s.category, 
    COUNT(js.job_id) AS demand_count
FROM skills s
JOIN job_skills js ON s.id = js.skill_id
GROUP BY s.id, s.skill_name, s.category
ORDER BY demand_count DESC
LIMIT 10;


SELECT 
    clean_title, 
    experience_years_min, 
    salary_max
FROM jobs
WHERE salary_max IS NOT NULL AND experience_years_min IS NOT NULL
ORDER BY experience_years_min ASC, salary_max DESC
LIMIT 10;
-------------------------------
SELECT 
    j.experience_years_min AS min_years_required,
    STRING_AGG(DISTINCT j.experience_level::text, ' vs ') AS conflicting_levels,
    COUNT(j.id) AS total_jobs_affected
FROM jobs j
WHERE j.experience_years_min IS NOT NULL 
  AND j.experience_level IS NOT NULL
GROUP BY j.experience_years_min
HAVING COUNT(DISTINCT j.experience_level) > 1
ORDER BY j.experience_years_min;

SELECT 
    j.clean_title,
    c.name AS company_name,
    j.experience_level,
    j.experience_years_min,
    j.experience_years_max
FROM jobs j
LEFT JOIN companies c ON c.id = j.company_id
WHERE j.experience_years_min = 3
ORDER BY j.experience_level, j.clean_title;

SELECT 
    j.experience_years_min AS min_years,
    j.experience_level,
    COUNT(*) AS total_jobs,
    STRING_AGG(DISTINCT j.clean_title, ' | ') AS sample_titles
FROM jobs j
WHERE j.experience_years_min IS NOT NULL 
  AND j.experience_level IS NOT NULL
GROUP BY j.experience_years_min, j.experience_level
ORDER BY j.experience_years_min ASC, j.experience_level;

---------------------------------------
SELECT 
	j.clean_title AS job_title,
	j.experience_range AS experience,
	j.experience_level AS level,
	c.name AS company_name,
	j.posted_date
FROM jobs j
LEFT JOIN companies c ON c.id=j.id
WHERE j.clean_title IN ('Frontend Developer', 'Backend Developer','Mobile Developer') 
  AND j.experience_level = 'Junior' 
  AND c.name IS NOT NULL
-----------------------------------

SELECT
	s.skill_name,
	COUNT(js.skill_id)
FROM skills s
LEFT JOIN job_skills js ON s.id=js.skill_id
GROUP BY s.skill_name
ORDER BY COUNT(js.skill_id) DESC
LIMIT 10;
----------------------------------



SELECT 
    j.clean_title,
    COUNT(DISTINCT j.id) AS total_jobs,
    COUNT(DISTINCT CASE WHEN s.category IN ('DevOps', 'Cloud') OR s.skill_name IN ('Docker', 'CI/CD', 'AWS', 'Azure') THEN j.id END) AS jobs_requiring_devops,
    ROUND(
        (COUNT(DISTINCT CASE WHEN s.category IN ('DevOps', 'Cloud') OR s.skill_name IN ('Docker', 'CI/CD', 'AWS', 'Azure') THEN j.id END)::numeric / COUNT(DISTINCT j.id)) * 100, 1
    ) AS devops_requirement_percentage
FROM jobs j
JOIN job_skills js ON j.id = js.job_id
JOIN skills s ON js.skill_id = s.id
WHERE j.clean_title IN ('Backend Developer', 'Frontend Developer', 'Full Stack Developer', 'Mobile Developer')
GROUP BY j.clean_title
ORDER BY devops_requirement_percentage DESC;






