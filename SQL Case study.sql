-- SQL Query using the Famous Paintings & Museum dataset: --

select * from artist
select * from canvas_size
select * from image_link
select * from museum
select * from museum_hours
select * from product_size
select * from subject
select * from work



--1) Fetch all the paintings which are not displayed on any museums?

select work_id,name 
from work
where museum_id is null

--2) Are there museuems without any paintings?

select *
from museum as m right join work as w
on  w.museum_id = m.museum_id
where work_id is null

--3) How many paintings have an asking price of more than their regular price? 

select count(*) as painting_count
from product_size
where sale_price > regular_price

--4) Identify the paintings whose asking price is less than 50% of its regular price

select p.work_id, name 
from product_size p left join work w
on p.work_id = w.work_id
where sale_price < 0.5 * regular_price

--5) Which canva size costs the most?

select TOP 1 label,sale_price ,rank() over(order by sale_price desc) as cost_rank
from product_size p  left join canvas_size c
on p.size_id = cast(c.size_id as nvarchar)

--6) Delete duplicate records from work, product_size and subject

-- Subject --

with del as
(
SELECT *, ROW_NUMBER() OVER (PARTITION BY [work_id], [subject] ORDER BY (SELECT NULL)) AS r
FROM subject
)
delete from del where r > 1

-- work -- 

with del as
(
SELECT *, ROW_NUMBER() OVER (PARTITION BY work_id, name, artist_id,style,museum_id ORDER BY (SELECT NULL)) AS r
FROM work
)
delete from del where r > 1

-- product size -- 

with del as
(
SELECT *, ROW_NUMBER() OVER (PARTITION BY work_id, size_id, sale_price,regular_price ORDER BY (SELECT NULL)) AS r
FROM product_size
)
delete from del where r > 1

--7) Identify the museums with invalid city information in the given dataset

SELECT *
FROM museum
WHERE PATINDEX('%[0-9]%', city) = 1;

--8) Museum_Hours table has 1 invalid entry. Identify it and remove it.

with invalid as
(
select *,ROW_NUMBER() over( partition by museum_id,day order by (select null) ) as r
from museum_hours 
)
delete from invalid
where r > 1

--9) Fetch the top 10 most famous painting subject

select top 10 s.subject,count(1) as no_of_paintings,rank() over(order by count(1) desc) as ranking
from work w join subject s 
on s.work_id=w.work_id		
group by s.subject 

--10) Identify the museums which are open on both Sunday and Monday. Display museum name, city.

select name, city
from museum
where museum_id in(
select museum_id
from museum_hours
where museum_id in 
(
select museum_id
from museum_hours
where day = 'Monday'
) and day = 'Sunday'
)

--11) How many museums are open every single day?

with museum_open as
(
select museum_id , count(*) as opendays
from museum_hours
group by museum_id having count(museum_id) = 7
)
select count(*) as museum_count from museum_open

--12) Which are the top 5 most popular museum? (Popularity is defined based on most no of paintings in a museum)

with count_paint as
(
select museum_id, count(*) as painting_count
from work
group by museum_id
)
select top 5 name, painting_count
from museum m left join count_paint as c
on m.museum_id = c.museum_id
order by painting_count desc

--13) Who are the top 5 most popular artist? (Popularity is defined based on most no of paintings done by an artist)

select top 5 full_name, count(work_id) as no_of_paintings , rank() over(order by count(a.artist_id) desc ) as rank
from work w left join artist a
on w.artist_id = a.artist_id
group by full_name

--14) Display the 10 least popular canva sizes

select top 10 label,count(label) as no_of_painting   
from work w 
left join product_size p on w.work_id = p.work_id
left join canvas_size c on cast(c.size_id as nvarchar) = p.size_id
group by label
order by count(1)

--15) Which museum is open for the longest during a day. Dispay museum name, state and hours open and which day?

create function convert_time (@input varchar(50))
returns time
as
begin
declare @time time;
declare @hour int , @mins int , @period char(2);
set @hour = cast(substring(@input,1,CHARINDEX(':',@input)-1) as int);
set @mins = cast(substring(@input,CHARINDEX(':',@input)+1,2) as int);
set @period = right(@input,2)
IF @period = 'PM' AND @hour < 12
SET @hour = @hour + 12;
IF @period = 'AM' AND @hour = 12
SET @hour = 0;
SET @time = convert(time,convert(char(2),@hour)+':'+convert(char(2),@mins),8);
return @time;
end;

select top 1 name,state,datediff(minute,dbo.convert_time([open]),dbo.convert_time([close])) as duration, day
from museum_hours mh left join museum m
on mh.museum_id = m.museum_id
order by duration desc

--16) Which museum has the most no of most popular painting style?

with pop_style as 
(select style,rank() over(order by count(1) desc) as rnk
from work
group by style),
cte as
(select w.museum_id,m.name as museum_name,ps.style, count(1) as no_of_paintings ,rank() over(order by count(1) desc) as rnk
from work w
join museum m on m.museum_id=w.museum_id
join pop_style ps on ps.style = w.style
where w.museum_id is not null and ps.rnk=1
group by w.museum_id, m.name,ps.style)
select museum_name,style,no_of_paintings
from cte 
where rnk=1;



--17) Identify the artists whose paintings are displayed in multiple countries

select * from artist
where artist_id in (
select artist_id
from work w left join museum m
on w.museum_id = m.museum_id
group by artist_id having count(distinct country) > 1)

--18) Display the country and the city with most no of museums. Output 2 seperate columns to mention the city and country. If there are multiple value, seperate them with comma.
	
with cte_city as
( select city, count(1) as museum_count, rank() over (order by count(1) desc ) as rank
from museum
group by city having city is not null),
cte_country as 
( select country, count(1) as museum_count, rank() over (order by count(1) desc ) as rank
from museum
group by country having country is not null)
select(
select STRING_AGG(country,',') from cte_country where rank =1) as popular_country,
(select STRING_AGG(city,',') from cte_city where rank =1) as popular_city

--19) Identify the artist and the museum where the most expensive and least expensive painting is placed. Display the artist name, sale_price, painting name, museum name, museum city and canvas label

with cte as 
(select *, rank() over(order by sale_price desc) as most, rank() over(order by sale_price ) as bottom
from product_size )
select full_name as artist_name,sale_price,w.name as painting_name,m.name as museum_name,m.city,label,
case when most = 1 then 'most expensive' when bottom = 1 then 'least expensive' end as comment
from work w
left join cte p on w.work_id = p.work_id
left join artist a on w.artist_id = a.artist_id
left join museum m on w.museum_id = m.museum_id
left join canvas_size c on p.size_id = cast(c.size_id as varchar)
where most = 1 or bottom = 1


--20) Which country has the 5th highest no of paintings?

with cte as 
(select m.country, count(1) as no_of_Paintings, rank() over(order by count(1) desc) as rnk
from work w join museum m 
on m.museum_id=w.museum_id
group by m.country)
select country, no_of_Paintings from cte 
where rnk=5;

--21) Which are the 3 most popular and 3 least popular painting styles?

with cte as (
select style,count(1) as counts, rank() over (order by count(1)) as bottom,rank() over (order by count(1) desc) as popular
from work
where style is not null
group by style)
select style, case when popular <= 3 then '3 most popular' when bottom <= 3 then '3 least popular' end as comment
from cte
where bottom <= 3 or popular <= 3

--22) Which artist has the most no of Portraits paintings outside USA?. Display artist name, no of paintings and the artist nationality.

select full_name as artist_name, nationality, no_of_paintings
from (
select a.full_name, a.nationality,count(1) as no_of_paintings,rank() over(order by count(1) desc) as rnk
from work w
join artist a on a.artist_id=w.artist_id
join subject s on s.work_id=w.work_id
join museum m on m.museum_id=w.museum_id
where s.subject='Portraits' and m.country != 'USA'
group by a.full_name, a.nationality) x
where rnk=1;	

	