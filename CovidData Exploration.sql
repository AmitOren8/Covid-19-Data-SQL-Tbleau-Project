-- The complete CovidDeaths table
select * 
from CovidDeaths$
order by 3,4


-- The complete CovidVaccinations table
select * 
from CovidVaccinations$
order by 3,4

------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------

-- 1. Exploring Locations Data

-- Unique locations table
select distinct(location)
from CovidDeaths$
order by 1
-- We can see the data includes both countries and continents.


-- 1.1. Let's see unique locations for non-countries.
select distinct(location)
from CovidDeaths$
where continent is null
order by 1
-- We can see that the loaction column includes entries for income level and the European Union.


-- 1.2. Select data to use by countries.
select location, date, total_cases, new_cases, total_deaths
from CovidDeaths$
where continent is not null
order by 1,2


-- 1.3. Select data to use by continents.
select location, date, total_cases, new_cases, total_deaths
from CovidDeaths$
where continent is null and location not in ('High income', 'Upper middle income', 'Lower middle income', 'Low income', 'European Union')
order by 1,2


-- 1.4. Select data to use by income level.
select location, date, total_cases, new_cases, total_deaths
from CovidDeaths$
where continent is null and location in ('High income', 'Upper middle income', 'Lower middle income', 'Low income')
order by 1,2

------------------------------------------------------------------------------------------------------------------

-- 2. Exploring Covid-19 cases and deaths data by countries 

-- 2.1. Total Cases vs Total Deaths by country. 
-- Likelihood of dying if contracted with covid-19 in every country.
select 
	location,  
	max(total_cases) as total_infected, 
	max(cast(total_deaths as int)) as total_deceased, -- In original data the total_deaths column is type nvarchar.
	round((max(total_deaths)/max(total_cases)*100), 3) as precentage_deceased_of_total_infected
from CovidDeaths$
where continent is not null
--where location = 'israel'
group by location
order by 4 desc


-- 2.1.1. North Korea shows non-logical resultes, let's review North Korea's data.
select location, date, total_cases, new_cases, cast(total_deaths as int) as total_deaths
from CovidDeaths$
where location = 'North Korea'
order by 1, 2 
-- It seems like the North Korean data was either incorrectly entered or is unreliable.


-- 2.2. Total Cases vs Population by country
-- Precentage of the population that contracted covid-19 per country.
select 
	location, 
	population, 
	max(total_cases) as total_infected, 
	max((total_cases/population))*100 as precentage_infected
from CovidDeaths$
where continent is not null
--where location = 'israel'
group by location, population
order by 4 desc
	

-- 2.3. Total Deaths vs Population by country
-- Precentage of the population that died of covid-19 per country.
select 
	location, 
	population, 
	max(cast(total_deaths as int)) as total_deceased, 
	max((total_deaths/population))*100 as precentage_deceased_of_population
from CovidDeaths$
where continent is not null
--where location = 'israel'
group by location, population
order by 4 desc

------------------------------------------------------------------------------------------------------------------

--3. Exploring Covid-19 Data by Continent.
select 
	location,
	population,
	max(total_cases) as total_cases,
	round((max((total_cases/population))*100), 3) as precentage_infected,
	max(cast(total_deaths as int)) as total_deaths,
	round((max((total_deaths/population))*100), 3) as precentage_deceased_of_population,
	round((max(total_deaths)/max(total_cases)*100), 3) as precentage_deceased_of_total_infected
from CovidDeaths$
where continent is null and location not in ('High income', 'Upper middle income', 'Lower middle income', 'Low income', 'European Union')
group by location, population
order by 2 desc

------------------------------------------------------------------------------------------------------------------

-- 4. Exploring Income Level Covid-19 Data
select 
	location,
	population,
	max(total_cases) as total_cases,
	round((max((total_cases/population))*100), 3) as precentage_infected,
	max(cast(total_deaths as int)) as total_deaths,
	round((max((total_deaths/population))*100), 3) as precentage_deceased_of_population,
	round((max(total_deaths)/max(total_cases)*100), 3) as precentage_deceased_of_total_infected
from CovidDeaths$
where continent is null and location in ('High income', 'Upper middle income', 'Lower middle income', 'Low income')group by location, population
order by 2 desc

------------------------------------------------------------------------------------------------------------------

-- 5. Exploring Global Covid-19 Data.

-- 5.1. Global Covid-19 cases growth rates
with running_sum_cases as (
select 
	date,
	new_cases,
	sum_new_cases,
	lag(sum_new_cases, 1) over (order by date) as prev_new_cases
from (select
		cast(date as date) as date, -- date column is in datetime fromt in original table.
		new_cases,
		sum(new_cases) over (order by date rows between unbounded preceding and current row) as sum_new_cases
	from CovidDeaths$) as a
where new_cases >= 1)

select
	date,
	new_cases,
	sum_new_cases,
	prev_new_cases,
	round((new_cases / prev_new_cases)*100, 3) as cases_precentage_growth
from running_sum_cases
where prev_new_cases != 0


-- 5.2. Global Covid-19 cases growth rates
with running_sum_deaths as (
select 
	date,
	new_deaths,
	sum_new_deaths,
	cast((lag(sum_new_deaths, 1) over (order by date)) as int) as prev_new_deaths
from (select
		cast(date as date) as date, -- date column is in datetime fromt in original table.
		cast(new_deaths as float) as new_deaths,
		sum(cast(new_deaths as float)) over (order by date rows between unbounded preceding and current row) as sum_new_deaths
	from CovidDeaths$) as a
where new_deaths >= 1)

select
	date,
	new_deaths,
	sum_new_deaths,
	prev_new_deaths,
	round((new_deaths / prev_new_deaths)*100, 3) as cases_precentage_growth
from running_sum_deaths
where prev_new_deaths != 0

------------------------------------------------------------------------------------------------------------------

-- 6. Joining deaths and vaccinations tabels.

select * 
from CovidDeaths$ as d
join CovidVaccinations$ as v
	on d.location = v.location
	and d.date = v.date

------------------------------------------------------------------------------------------------------------------

-- 7. Vaccinations in population by country
-- Using temp table 

drop table if exists #PercentPopulationVaccinated
create table #PercentPopulationVaccinated
(
location nvarchar(225),
date datetime,
population numeric,
new_vaccinations numeric,
sum_vaccinations numeric
)

insert into #PercentPopulationVaccinated
select *, sum(new_vaccinations) over (partition by location order by location, date) as sum_vaccinations	
from (select
			d.location,
			convert(date, d.date) as date,
			cast(d.population as float) as population,
			cast(v.new_people_vaccinated_smoothed as float) as new_vaccinations
	from CovidDeaths$ as d
	join CovidVaccinations$ as v
		on d.location = v.location
		and d.date = v.date
	where d.continent is not null) as a
where new_vaccinations is not null


select *, round((sum_vaccinations / population)*100, 6) as percent_vaccinated
from #PercentPopulationVaccinated
