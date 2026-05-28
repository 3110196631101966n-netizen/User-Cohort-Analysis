--- Підсумквоий проект блоку 1.
--- Завдання 1

-- Перевірка 1

select *
from public.cohort_users_raw
limit 10;

-- Перевірка 2

select *
from public.cohort_events_raw
limit 10;

-- При виконанні цих запитів я ознайомилась з двома таблицями (cohort_users_raw та cohort_events_raw) 
-- та побачила особливості полів signup_datetime та event_datetime. Вони в тому, що це текст у різних 
-- форматах дат (day-month-year, різні розділювачі, інколи двозначний рік), 
-- а в event_type можуть бути технічні значення (наприклад, test_event) або NULL.

-- Крок 1. Підготовка користувачів (userse). 
-- Створюю першу CTE для очищення дат у cohort_users_raw:

-- Спочатку позбуваюсь зайвих пробілів (trim), та компонентів часу (split_part), 
-- Заміняю різні делімітери (. /) на єдиний за допомогою replace. Перевіряю. Перевірка 3. 

select
    u.signup_datetime,
    replace(
        replace(
            split_part(trim(u.signup_datetime), ' ', 1),
        '.', '-'),
    '/', '-') as clean_date
from cohort_users_raw u
limit 20;

-- Створюю першу CTE, використовую CASE для перевірки формату дат.
-- Застосувую функцію to_date(…, format) для конвертації у timestamp.
-- Тестую запит та перевіряю коректність перетворення. Перевірка 4. 

with users_parsed as 
    (
    
	select
	    user_id,
        signup_datetime,
	    promo_signup_flag,
	    case 
	        when length(split_part(clean_date, '-', 3)) = 4
	            then to_date(clean_date, 'DD-MM-YYYY')
	        when length(split_part(clean_date, '-', 3)) = 2
	            then to_date(clean_date, 'DD-MM-YY')
	        else null
	    end as signup_ts 
	from 
		(
	    select *,
	        replace(
	            replace(
	                split_part(trim(u.signup_datetime), ' ', 1),
	            '.', '-'),
	        '/', '-') as clean_date
	    from cohort_users_raw u	   
		) t	

-- Крок 2. Підготовка подій (events).
-- Створюю другу CTE для очищення дат у cohort_events_raw:

-- Спочатку позбуваюсь зайвих пробілів (trim), та компонентів часу (split_part), 
-- Заміняю різні делімітери (. /) на єдиний за допомогою replace. Перевіряю. Перевірка 5. 

select
    e.event_datetime,
    replace(
        replace(
            split_part(trim(e.event_datetime), ' ', 1),
        '.', '-'),
    '/', '-') as clean_date
from cohort_events_raw e
limit 20;

-- Створюю другу CTE, використовую CASE для перевірки формату дат.
-- Застосувую функцію to_date(…, format) для конвертації у timestamp.
-- Тестую запит та перевіряю коректність перетворення. Перевірка 6. 

events_parsed as 
    (
    
	select
	    user_id,
	    event_type,
	    case 
	        when length(split_part(clean_date, '-', 3)) = 4
	            then to_date(clean_date, 'DD-MM-YYYY')
	        when length(split_part(clean_date, '-', 3)) = 2
	            then to_date(clean_date, 'DD-MM-YY')
	        else null
	    end as event_ts 
	from 
		(
	    select *,
	        replace(
	            replace(
	                split_part(trim(e.event_datetime), ' ', 1),
	            '.', '-'),
	        '/', '-') as clean_date
	    from cohort_events_raw e
		) t	


--- Крок 3. Об'єднання користувачів і подій і розрахунок когорт:
--- 3.1. Об'єднала очищені таблиці CTE за допомогою функції JOIN за полем user_id, перетворила 
--- дати у формат рік-місяць для cohort_month, розрахувала різницю в місяцях (month_offset) 
--- між подією та реєстрацією. Застосувала фільтрацію даних - виключила: користувачів з відсутньою датою реєстрації,
--- події з відсутньою датою, події без типу (event_type IS NULL), тестові події (event_type = 'test_event').
--- Залишила подію 'registration' як активність у 0-му місяці. Перевірила, чи працює схема.
--- Перевірка 7. 


with users_parsed as 
    (   
	select
	    user_id,
	    promo_signup_flag,
	    case 
	        when length(split_part(clean_date, '-', 3)) = 4
	            then to_date(clean_date, 'DD-MM-YYYY')
	        when length(split_part(clean_date, '-', 3)) = 2
	            then to_date(clean_date, 'DD-MM-YY')
	        else null
	    end as signup_ts 
	from 
		(
	    select 
	    	    user_id,
	            promo_signup_flag,
		        replace(
		            replace(
		                split_part(trim(signup_datetime), ' ', 1),
		            '.', '-'),
		        '/', '-') as clean_date
	    from cohort_users_raw 	   
		) t	
	 ),
	 events_parsed as 
    (    
	select
	    user_id,
	    event_type,
	    case 
	        when length(split_part(clean_date, '-', 3)) = 4
	            then to_date(clean_date, 'DD-MM-YYYY')
	        when length(split_part(clean_date, '-', 3)) = 2
	            then to_date(clean_date, 'DD-MM-YY')
	        else null
	    end as event_ts 
	from 
		(
	    select 
           user_id,
	       event_type,
	       replace(
	           replace(
	               split_part(trim(event_datetime), ' ', 1),
	            '.', '-'),
	        '/', '-') as clean_date
	    from cohort_events_raw 
		) t	
	),
    user_activity as 
	    (
	    select
	        u.user_id,
	        u.promo_signup_flag,
	        date_trunc('month', u.signup_ts)::date as cohort_month,
	        date_trunc('month', e.event_ts) as activity_month,
	        date_part('month', age(e.event_ts, u.signup_ts)) as month_offset
	    from users_parsed u
	    join events_parsed e
	        on u.user_id = e.user_id
	    where
	        u.signup_ts is not null
	        and e.event_ts is not null
	        and e.event_type is not null
	        and e.event_type <> 'test_event'
	)
select *
from user_activity
limit 20;	
		
--- 3.2. Побудувала фінальну агреговану таблицю: Додала групування за promo_signup_flag, cohort_month, month_offset.
--- Розрахувала users_total (COUNT DISTINCT user_id). Обмежила період спостереження: січень-червень 2025.
--- Відсортувала за promo_signup_flag, cohort_month, month_offset. Перевірка 8.
		
				
with users_parsed as 
    (   
	select
	    user_id,
	    promo_signup_flag,
	    case 
	        when length(split_part(clean_date, '-', 3)) = 4
	            then to_date(clean_date, 'DD-MM-YYYY')
	        when length(split_part(clean_date, '-', 3)) = 2
	            then to_date(clean_date, 'DD-MM-YY')
	        else null
	    end as signup_ts 
	from 
		(
	    select 
	    	    user_id,
	            promo_signup_flag,
		        replace(
		            replace(
		                split_part(trim(signup_datetime), ' ', 1),
		            '.', '-'),
		        '/', '-') as clean_date
	    from cohort_users_raw 	   
		) t	
	 ),
	 events_parsed as 
    (    
	select
	    user_id,
	    event_type,
	    case 
	        when length(split_part(clean_date, '-', 3)) = 4
	            then to_date(clean_date, 'DD-MM-YYYY')
	        when length(split_part(clean_date, '-', 3)) = 2
	            then to_date(clean_date, 'DD-MM-YY')
	        else null
	    end as event_ts 
	from 
		(
	    select 
           user_id,
	       event_type,
	       replace(
	           replace(
	               split_part(trim(event_datetime), ' ', 1),
	            '.', '-'),
	        '/', '-') as clean_date
	    from cohort_events_raw 
		) t	
	),
    user_activity as 
	    (
	    select
	        u.user_id,
	        u.promo_signup_flag,
	        date_trunc('month', u.signup_ts)::date as cohort_month,
	        date_trunc('month', e.event_ts) as activity_month,
	        date_part('month', age(e.event_ts, u.signup_ts)) as month_offset
	    from users_parsed u
	    join events_parsed e
	        on u.user_id = e.user_id
	    where
	        u.signup_ts is not null
	        and e.event_ts is not null
	        and e.event_type is not null
	        and e.event_type <> 'test_event'
	)	
select
    promo_signup_flag,
    cohort_month,
    month_offset,
    count(distinct user_id) as users_total
from user_activity
where activity_month between '2025-01-01'
   and '2025-06-30'
group by
    promo_signup_flag,
    cohort_month,
    month_offset
order by
    promo_signup_flag,
    cohort_month,
    month_offset;	
