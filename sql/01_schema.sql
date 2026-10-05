-- PostgreSQL. Run once in a dedicated empty database.
-- The source CSV is loaded into raw_jobs before running 02_transform.sql.
CREATE TABLE raw_jobs (
    raw_job_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    job_title text,
    company_name text,
    origin_type text,
    city text,
    country text,
    source text,
    experience_level text,
    experience_years_min integer,
    experience_years_max integer,
    job_type text,
    posted_date date,
    salary text,
    skills text,
    description text
);

CREATE TABLE companies (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name text NOT NULL UNIQUE
);

CREATE TABLE locations (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    city text,
    country text NOT NULL
);
CREATE UNIQUE INDEX locations_natural_key
    ON locations (coalesce(city, ''), country);

CREATE TABLE job_sources (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_name text NOT NULL UNIQUE
);

CREATE TABLE jobs (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    raw_job_id bigint NOT NULL UNIQUE REFERENCES raw_jobs(raw_job_id),
    title text NOT NULL,
    clean_title text,
    company_id bigint REFERENCES companies(id),
    location_id bigint REFERENCES locations(id),
    source_id bigint REFERENCES job_sources(id),
    origin_type text,
    experience_level text,
    experience_years_min integer,
    experience_years_max integer,
    experience_range text,
    job_type text,
    posted_date date,
    description text,
    salary_min integer,
    salary_max integer,
    CONSTRAINT nonnegative_experience CHECK (experience_years_min IS NULL OR experience_years_min >= 0),
    CONSTRAINT valid_experience CHECK (experience_years_min IS NULL OR experience_years_max IS NULL OR experience_years_max >= experience_years_min),
    CONSTRAINT valid_salary CHECK (salary_min IS NULL OR salary_max IS NULL OR salary_max >= salary_min)
);

CREATE TABLE skills (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    skill_name text NOT NULL UNIQUE,
    category text
);

CREATE TABLE job_skills (
    job_id bigint NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    skill_id bigint NOT NULL REFERENCES skills(id) ON DELETE CASCADE,
    PRIMARY KEY (job_id, skill_id)
);
CREATE INDEX job_skills_skill_id_idx ON job_skills(skill_id);
