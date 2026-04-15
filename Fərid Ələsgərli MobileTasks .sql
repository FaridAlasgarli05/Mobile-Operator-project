-- 1. Abonentlərin son 3 ayda istifadə etdiyi xidmətlərin adlarını və istifadə sayını göstər:
--Ekrana abonentin adı, soyadı, xidmətin adı və istifadə sayı çıxsın.
 
 
 -- 1 ci üsul: son 3 ayda ancaq istifadə olunan xidmətlər ekranda əks olunur.
    select 
    su.name,
    su.surname,
    sv.service_name,
    count(*) as istifade_sayi
from (
    select caller_id as subscribers_id, service_id
    from calls
    where call_date >= add_months(sysdate, -3)                  -- zəng xidməti

    union all

    select sender_id as subscribers_id, service_id
    from sms_informations
    where sms_date >= add_months(sysdate, -3)                   -- sms xidməti  

) t
join subscribers su
  on su.subscribers_id = t.subscribers_id
join services sv
  on sv.service_id = t.service_id
group by su.name, su.surname, sv.service_name
order by su.name, su.surname, sv.service_name;


-- 2 ci üsul:  hər abonent üçün bütün xidmətləri göstərmək

select 
    su.name,
    su.surname,
    sv.service_name,
    nvl(count(t.service_id), 0) as istifade_sayi
from subscribers su
cross join services sv  
 left join (
    select caller_id as subscribers_id, service_id
    from calls
    where call_date >= add_months(sysdate, -3)

    union all

    select sender_id as subscribers_id, service_id
    from sms_informations
    where sms_date >= add_months(sysdate, -3)
) t
on t.subscribers_id = su.subscribers_id
and t.service_id = sv.service_id
group by su.name, su.surname, sv.service_name
order by su.name, su.surname, sv.service_name;







      
--2.Hər abonent üçün son ödəniş tarixini və məbləğini göstər: 
--    Ekrana Ad, soyad, son ödəniş tarixi, məbləği və ödənişin üsulu haqqında informasiyalar çıxsın.


-- 1 ci üsul: subquery ilə

select
    s.name,
    s.surname,
    p.payment_id,
    p.amount,
    p.payment_date as son_odenis_tarixi,
    pm.name as odenis_usulu
from subscribers s
join payments p 
  on p.subscribers_id = s.subscribers_id
join payment_method_type pm 
  on p.payment_type_id = pm.payment_type_id
where (p.payment_date, p.payment_id) = (
    select max(p2.payment_date), max(p2.payment_id)
    from payments p2
    where p2.subscribers_id = p.subscribers_id
)
order by s.name,
         s.surname,
         p.payment_id,
         p.amount,
         p.payment_date,
         pm.name;


-- 2 ci üsul: analitik funksiyalar(row_number) ilə

select
    s.name,
    s.surname,
    p.payment_id,
    p.amount,
    p.payment_date as son_odenis_tarixi,
    pm.name as odenis_usulu
from subscribers s
join (
    select *
    from (
        select p.*,
               row_number() over (partition by p.subscribers_id order by p.payment_date desc, p.payment_id desc) as rn
        from payments p
    )
    where rn = 1
) p on s.subscribers_id = p.subscribers_id
join payment_method_type pm
  on p.payment_type_id = pm.payment_type_id
order by s.name, s.surname;



            
-- 3.Aktiv xidmətlər üzrə abonentlərin sayını və ümumi ödəniş məbləğini göstər:
--    Ekrana xidmətin adı,abonentlərin sayını və ümumi ödəniş məbləği haqqında informasiyalar çıxsın. 


    
    
    
select 
    sv.service_name,
    count(distinct t.subscribers_id) as abonent_sayi,
    sum(p.amount) as umumi_odenis
from (
       select caller_id as subscribers_id, service_id
       from calls                                              --zəng xidməti

       union all

       select sender_id as subscribers_id, service_id   
       from sms_informations                                   -- sms xidməti    

) t
join services sv
   on sv.service_id = t.service_id
 join payments p
   on p.subscribers_id = t.subscribers_id
where sv.deactivation_date is null or sv.deactivation_date > sysdate
group by sv.service_name
order by sv.service_name;






     
-- 4.Hər abonent üçün edilən zənglərin sayını və ümumi zəng müddətini göstər:
--    Ekrana ad, soyad, abonent üçün edilən zənglərin sayını, ümumi zəng müddətini, zəngin tipi haqqında informasiyalar çıxsın.


-- 1 ci üsul: Yalnız zəng etmiş abonentlər ekranda göstəriləcək.
select su.name,
       su.surname,
       ct.name as zengin_tipi,
       count(c.call_id) as zeng_sayi,
       sum(c.call_duration) as umumi_zeng_muddeti
from calls c
 join subscribers su
  on c.caller_id = su.subscribers_id
 join call_type ct
  on c.call_type_id = ct.call_type_id
group by su.name, su.surname, ct.name
order by su.name, su.surname, ct.name;


-- 2 ci üsul: Bütün abonentlər ekranda göstəriləcək,hətta zəng etməsələr belə.

select 
    su.name,
    su.surname,
    nvl(ct.name, 'None') as zengin_tipi,
    count(c.call_id) as zeng_sayi,
    nvl(sum(c.call_duration), 0) as umumi_zeng_muddeti
from 
    subscribers su
    left join calls c
        on su.subscribers_id = c.caller_id
    left join call_type ct
        on c.call_type_id = ct.call_type_id
group by su.name,su.surname,ct.name
order by su.name,su.surname,ct.name;


    
 
--5.Hər abonent üçün tarifə görə aylıq ödədikləri məbləği və zənglərin sayını göstər:
--    Ekrana ad, soyad,tarifə görə aylıq ödədikləri məbləğ və zənglərin sayı haqqında informasiyalar çıxsın. 


-- 1 ci üsul: Yalnız xidmət istifadə etmiş abonentlər ekranda göstəriləcək.
select 
    su.name,
    su.surname,
    ti.tariff_name,
    ti.monthly_subscription as ayliq_odenis,
    count(t.service_id) as istifade_sayi
from 
    (
        select caller_id as subscribers_id, service_id
        from calls                                              --zəng xidməti
        union all
        select sender_id as subscribers_id, service_id
        from sms_informations                                   -- sms xidməti
    ) t
    join subscribers su on su.subscribers_id = t.subscribers_id
    join services se on se.service_id = t.service_id
    join tariff_informations ti on ti.tariff_id = se.tariff_id
group by su.name, su.surname, ti.tariff_name, ti.monthly_subscription
order by su.name, su.surname;



-- 2 ci üsul: Bütün abonentlər ekranda göstəriləcək,hətta xidmətdən istifadə etməsələr belə.


select 
    su.name,
    su.surname,
    nvl(ti.tariff_name,'None') as Tarif,
    nvl(ti.monthly_subscription,0) as ayliq_odenis,
    count(t.service_id) as istifade_sayi
from subscribers su
left join (
       select caller_id as subscribers_id, service_id
        from calls                                              --zəng xidməti
        union all
        select sender_id as subscribers_id, service_id
        from sms_informations                                   -- sms xidməti
) t on su.subscribers_id = t.subscribers_id
left join services se on se.service_id = t.service_id
left join tariff_informations ti on ti.tariff_id = se.tariff_id
group by su.name, su.surname, ti.tariff_name, ti.monthly_subscription
order by su.name, su.surname;

         
--6.Zənglərin növünə görə abonentlərin sayını və ümumi zəng müddətini göstər:
    
    

select 
    ct.name as zeng_novu,
    count(distinct c.caller_id) as abonentlerin_sayi,
    sum(c.call_duration) as umumi_zeng_muddeti
from calls c
join call_type ct
    on c.call_type_id = ct.call_type_id
group by ct.name
order by ct.name;




-- bu üsulda left join ilə yazaraq zəngi olmayan növləridə ekranda göstəririk.
-- Datada bütün növlərə uyğun zəng olduğu üçün yuxarıdakı ilə eyni nəticəni verir.

select
    ct.name as zeng_novu,
    count(distinct c.caller_id) as abonentlerin_sayi,
    sum(c.call_duration) as umumi_zeng_muddeti
from call_type ct
left join calls c
    on c.call_type_id = ct.call_type_id
group by ct.name
order by ct.name;



            
--7. Aktiv olmayan, lakin son 6 ayda ödəniş etmiş abonentləri tap.
--Ekrana ad, soyad, status və ödəniş tarixi çıxsın.


-- 1 ci üsul: Aktiv olmayan, lakin son 6 ayda ödəniş olunmuş bütün ödənişləri göstərir. 
select su.name,
       su.surname,
       su.status,
       p.payment_date
from subscribers su
join payments p
  on su.subscribers_id = p.subscribers_id
where su.status <> 'ACTIVE'
  and p.payment_date >= add_months(sysdate, -6)
order by su.name, su.surname, p.payment_date desc;



-- 2 ci üsul: Aktiv olmayan, lakin son 6 ayda ödəniş etmiş abonentləri göstərir. 

select 
    su.name,
    su.surname,
    su.status,
    max(p.payment_date) as last_payment
from subscribers su
join payments p
    on su.subscribers_id = p.subscribers_id
where su.status <> 'ACTIVE'
  and p.payment_date >= add_months(sysdate, -6)
group by su.name, su.surname, su.status
order by su.name;

    

              
--8.Son 6 ayda edilən ödənişlərin məbləğini və xidmətlərin sayını abonentlər üzrə göstər.
--    Ekrana abonentin adı, abonentin soyadı, xidmətlərin sayı və 6 ayda edilən ödənişlərin məbləği haqqında informasiyalar çıxsın.



-- 1 ci üsul: Yalnız xidmət istifadə etmiş abonentlər ekranda göstəriləcək.
select 
    su.name,
    su.surname,
    count(distinct t.service_id) as xidmetlerin_sayi,
    sum(p.amount) as odenislerin_meblegi
from (
        select caller_id as subscribers_id, service_id, call_date as action_date
        from calls                                           -- zəng xidməti
        where call_date >= add_months(sysdate, -6)

        union all

        select sender_id as subscribers_id, service_id, sms_date as action_date
        from sms_informations                                 -- sms xidməti
        where sms_date >= add_months(sysdate, -6)
) t
join subscribers su
  on su.subscribers_id = t.subscribers_id
join payments p 
  on su.subscribers_id = p.subscribers_id
  and p.payment_date >= add_months(sysdate, -6)
group by su.name, su.surname
order by su.name, su.surname;



-- 2 ci üsul: Bütün abonentlər ekranda göstəriləcək,hətta xidmətdən istifadə etməsələr belə.

select 
    su.name,
    su.surname,
    nvl(count(distinct t.service_id), 0) as xidmetlerin_sayi,
    nvl(sum(p.amount), 0) as odenislerin_meblegi
from subscribers su
left join (
               select caller_id as subscribers_id, service_id, call_date as action_date
        from calls                                           -- zəng xidməti
        where call_date >= add_months(sysdate, -6)

        union all

        select sender_id as subscribers_id, service_id, sms_date as action_date
        from sms_informations                                 -- sms xidməti
        where sms_date >= add_months(sysdate, -6)
) t on su.subscribers_id = t.subscribers_id
left join payments p 
    on su.subscribers_id = p.subscribers_id
    and p.payment_date >= add_months(sysdate, -6)
group by su.name, su.surname
order by su.name, su.surname;

    
     
--9.Abonentlərdən ən çox şikayət edən 10 nəfərin adını və şikayət sayını göstər:
--Ekrana ad, soyad və ümumi şikayət sayı çıxsın.

  
-- 1 ci üsul: subquery ilə və yalnız şikayəti olan abonentlər
    
select * 
from (
    select t.*, row_number() over (order by sikayet_sayi desc) as siralama
    from (
        select su.name, su.surname, count(cst.complaint_id) as sikayet_sayi
        from subscribers su
        join complaints_and_support_requests cst
          on su.subscribers_id = cst.subscribers_id
        group by su.name, su.surname
    ) t
) t
where siralama <= 10;


    
    
-- 2 ci üsul: fetch ilə və bütün abonentlər, şikayət etməsələr belə.
select 
    su.name,
    su.surname,
    nvl(count(cas.complaint_id), 0) as umumi_sikayet_sayi
from subscribers su
left join complaints_and_support_requests cas
  on su.subscribers_id = cas.subscribers_id
group by su.name, su.surname
order by umumi_sikayet_sayi desc,su.name,su.surname asc
fetch first 10 rows only;

 
--10. Hər abonent üçün son 12 ayda göndərilən SMS-lərin sayını və SMS məzmununu göstər:
    
    
-- 1 ci üsul: Yalnız son 12 ayda SMS göndərən abonentlər ekranda göstərilir.
select su.name, su.surname, count(si.sms_id) as sms_sayi, si.sms_content
from subscribers su
inner join sms_informations si
  on su.subscribers_id = si.sender_id
where si.sms_date >= add_months(sysdate, -12)
group by su.name, su.surname, si.sms_content
order by su.name, su.surname, si.sms_content;


-- 1 ci üsul ---> listagg ilə daha səliqəli belə yaza bilərik.

select su.name,
       su.surname,
       count(si.sms_id) as sms_sayi,
       listagg(si.sms_content, '; ') within group (order by si.sms_date) as sms_content
from subscribers su
join sms_informations si
  on su.subscribers_id = si.sender_id
 and si.sms_date >= add_months(sysdate, -12)
group by su.name, su.surname
order by su.name, su.surname;




-- 2 ci üsul: Bütün abonentlər ekranda göstərilir, hətta SMS göndərməsə belə.
select 
    su.name,
    su.surname,
    nvl(count(si.sms_id), 0) as sms_sayi,
    nvl(si.sms_content,'None') as sms_content
from subscribers su
left join sms_informations si
    on su.subscribers_id = si.sender_id
   and si.sms_date >= add_months(sysdate, -12)
group by su.name, su.surname, si.sms_content
order by su.name, su.surname, si.sms_content;



    
    
     
--11.Hər abonent üçün edilən zənglərin ümumi müddətini və ödəniş məlumatlarını göstər:    
--   Ekrana abonentin adı, abonentin soyadı, zənglərin ümumi müddətini ödəniş məlumatları haqqında informasiyalar çıxsın.


-- 1 ci üsul : Yalnız zəng etmiş abonentlər ekranda göstəriləcək.



select su.name,
       su.surname,
       sum(c.call_duration) as umumi_zeng_muddeti,
       sum(p.amount) as umumi_odenis
from subscribers su
 join calls c
  on su.subscribers_id = c.caller_id                  -- ödəniş məlumatı: payments
 join payments p
  on su.subscribers_id = p.subscribers_id
group by su.name, su.surname
order by su.name, su.surname;

-- 2 ci üsul : Bütün abonentlər ekranda göstəriləcək,zəng etməsələr belə.

select su.name,
       su.surname,
       nvl(sum(c.call_duration),0) as umumi_zeng_muddeti,
       nvl(sum(p.amount),0) as umumi_odenis
from subscribers su
left join calls c
  on su.subscribers_id = c.caller_id                  -- ödəniş məlumatı: payments
left join payments p
  on su.subscribers_id = p.subscribers_id
group by su.name, su.surname
order by su.name, su.surname;



select 
    s.name,
    s.surname,
    nvl(sum(c.call_duration),0) as umumi_zeng_muddeti,
    nvl(sum(c.call_duration * t.call_price),0) as umumi_odenis
from subscribers s
left join calls c
    on s.subscribers_id = c.caller_id                    -- ödəniş məlumatları: tarif
left join services ser
    on c.service_id = ser.service_id
left join tariff_informations t
    on ser.tariff_id = t.tariff_id
group by s.name, s.surname
order by s.name, s.surname;


  
      
--12. Hər tarif üzrə abonentlərin aylıq ödədikləri məbləğin orta dəyərini və zənglərin sayını göstər:
--   Ekrana tarif adı, abonentlərin aylıq ödədikləri məbləğin orta dəyəri və zənglərin sayı haqqında informasiyalar çıxsın. 


    
-- 1 ci üsul : Yalnız istifadə olunan tariflər və zənglər ekranda göstəriləcək
    

select 
    ti.tariff_name,
    round(avg(ti.monthly_subscription),2) as ayliq_odenilen_meblegin_orta_deyeri,
    count(c.call_id) as zenglerin_sayi
from tariff_informations ti
join services se
    on ti.tariff_id = se.tariff_id
join calls c
    on c.service_id = se.service_id
group by ti.tariff_name
order by ti.tariff_name;


-- 2 ci üsul : Bütün tariflər və zənglər ekranda göstəriləcək,hətta istifadə olunmasa belə.


select 
    ti.tariff_name,
    round(avg(ti.monthly_subscription),2) as ayliq_odenilen_meblegin_orta_deyeri,
    nvl(count(c.call_id),0) as zenglerin_sayi
from tariff_informations ti
left join services se
    on ti.tariff_id = se.tariff_id
left join calls c
    on c.service_id = se.service_id
group by ti.tariff_name
order by ti.tariff_name;



select 
    t.tariff_name,
    nvl(round(avg(t.monthly_subscription + (c.call_duration * t.call_price)),1),0) as ayliq_odenilen_meblegin_orta_deyeri,
    count(c.call_id) as zenglerin_sayi
from tariff_informations t left join services ser 
    on ser.tariff_id = t.tariff_id 
    left join calls c
    on c.service_id = ser.service_id
    left join subscribers s
    on s.subscribers_id = c.caller_id
group by t.tariff_name
order by t.tariff_name;
    
    
  

--13. Hər abonent üçün son 12 ayda göndərilən SMS-lərin məzmununu və göndərilən SMS növlərini göstər:
--   Ekrana abonentin adı, soyadı, son 12 ayda göndərilən SMS-lərin məzmununu və göndərilən SMS növləri haqqında informasiyalar çıxsın. 



-- 1 ci üsul: Yalnız son 12 ayda SMS göndərən abonentlər ekranda göstərilir.
select su.name,
       su.surname,
       si.sms_content,
       st.name as sms_novu
from subscribers su
join sms_informations si
  on su.subscribers_id = si.sender_id
join sms_types st
  on si.sms_type_id = st.sms_type_id
where si.sms_date >= add_months(sysdate, -12)
order by su.name, su.surname, si.sms_date;


-- 1 ci üsul ---> listagg ilə daha səliqəli belə yaza bilərik.

select su.name,
       su.surname,
       listagg(si.sms_content, '; ') within group (order by si.sms_date) as sms_məzmunu,
       listagg(st.name, '; ') within group (order by si.sms_date) as sms_novu
from subscribers su
join sms_informations si
  on su.subscribers_id = si.sender_id
join sms_types st
  on si.sms_type_id = st.sms_type_id
where si.sms_date >= add_months(sysdate, -12)
group by su.name, su.surname
order by su.name, su.surname;





-- 2 ci üsul: Bütün abonentlər ekranda göstərilir, hətta SMS göndərməsə belə.
select su.name,
       su.surname,
       nvl(si.sms_content,'None') as sms_content,
       nvl(st.name,'None') as sms_novu
from subscribers su
left join sms_informations si
  on su.subscribers_id = si.sender_id
 and si.sms_date >= add_months(sysdate, -12)
left join sms_types st
  on si.sms_type_id = st.sms_type_id
order by su.name, su.surname, si.sms_date;







     


      
-- 14. Hər abonent üçün son 6 ayda edilən ödənişlərin məbləğini və xidmətlərin sayını göstər:
--   Ekrana abonentin adı, soyadı, son 6 ayda edilən ödənişlərin məbləğini və xidmətlərin sayı haqqında informasiyalar çıxsın.

  
  -- 1 ci üsul: Yalnız xidmətlərdən istifadə etmiş abonentlər ekranda göstəriləcək      
select 
    su.name,
    su.surname,
    sum(p.amount) as son_6_ay_odenis_meblegi,
    count(distinct t.service_id) as xidmetlerin_sayi
from (
    
        select caller_id as subscribers_id, service_id, call_date as action_date
        from calls                                      -- zəng xidməti
        where call_date >= add_months(sysdate, -6)

        union all

        select sender_id as subscribers_id, service_id, sms_date as action_date
        from sms_informations                           -- sms xidməti
        where sms_date >= add_months(sysdate, -6)
) t
join subscribers su
  on su.subscribers_id = t.subscribers_id
join payments p
  on su.subscribers_id = p.subscribers_id
 and p.payment_date >= add_months(sysdate, -6)
group by su.name, su.surname
order by su.name, su.surname;




  -- 2 ci üsul: Bütün abonentlər ekranda göstəriləcək,hətta xidmətlərdən istifadə etməsələr belə.     


select 
    su.name,
    su.surname,
    sum(p.amount) as son_6_ay_odenis_meblegi,
    count(distinct t.service_id) as xidmetlerin_sayi
from subscribers su
left join (
        
        select caller_id as subscribers_id, service_id, call_date as action_date
        from calls                                          -- Zəng xidməti
        where call_date >= add_months(sysdate, -6)

        union all

        select sender_id as subscribers_id, service_id, sms_date as action_date
        from sms_informations                                 -- SMS xidməti
        where sms_date >= add_months(sysdate, -6)
) t
  on su.subscribers_id = t.subscribers_id
left join payments p
  on su.subscribers_id = p.subscribers_id
 and p.payment_date >= add_months(sysdate, -6)
group by su.name, su.surname
order by su.name, su.surname;

       
-- 15. Hər abonent üçün ödənişlər və şikayətlərin məbləğini göstər:
--   Ekrana abonentin adı, soyadı, hər abonent üçün ödənişlər və şikayətlərin sayı haqqında informasiyalar çıxsın. 


-- 1 ci üsul: Yalnız ödəniş etmiş və şikayət göndərmiş abonentlər ekranda göstəriləcək.    
select su.name,
       su.surname,
       sum(p.amount) as umumi_odenis,
       count(cst.complaint_id) as sikayet_sayi
from subscribers su
 join payments p
  on su.subscribers_id = p.subscribers_id
 join complaints_and_support_requests cst
  on su.subscribers_id = cst.subscribers_id
group by su.name, su.surname
order by su.name, su.surname;


-- 2 ci üsul: Bütün abonentlər ekranda göstəriləcək,hətta ödəniş və şikayət etməsələr belə.
select 
    su.name,
    su.surname,
       sum(p.amount) as umumi_odenis,
       count(cst.complaint_id) as sikayet_sayi
from subscribers su
left join payments p
  on su.subscribers_id = p.subscribers_id
left join complaints_and_support_requests cst
  on su.subscribers_id = cst.subscribers_id
group by su.name, su.surname
order by su.name, su.surname;






      
-- 16. Abonentlərin yaş qrupuna görə və cinsiyyətə görə bölgüsünü göstər:
--    Yaş qrupları aşağıdakı şəkildədi
--    18 və aşağı
--    19-30
--    31-50
--    51 və yuxarı
--    Ekrana yaş aralığı,cins və say haqqında informasiyalar çıxsın.   


    
    
    select 
    case 
        when trunc(months_between(sysdate, su.birth_date)/12) <= 18 then '18 və aşağı'
        when trunc(months_between(sysdate, su.birth_date)/12) between 19 and 30 then '19-30'
        when trunc(months_between(sysdate, su.birth_date)/12) between 31 and 50 then '31-50'
        else '51 və yuxarı'
    end as yas_araligi,
    su.gender,
    count(subscribers_id) as abonent_sayi
from subscribers su
group by 
    (case 
        when trunc(months_between(sysdate, su.birth_date)/12) <= 18 then '18 və aşağı'
        when trunc(months_between(sysdate, su.birth_date)/12) between 19 and 30 then '19-30'
        when trunc(months_between(sysdate, su.birth_date)/12) between 31 and 50 then '31-50'
        else '51 və yuxarı'
    end,
    su.gender)
order by yas_araligi, su.gender;





       
-- 17. Hər abonentin ümumi ödədiyi məbləği və onların ödədikləri məbləğin tariflərin ortalama ödəmə məbləğindən yüksək olub 
--     olmadığını göstərən sorğu:

 -- 1 ci üsul: Hər bir abonentin ödədiyi ümumi məbləği bütün tariflərin ortalama məbləği ilə müqayisə edir. 
    
    select 
    su.name,
    su.surname,
    sum(p.amount) as umumi_mebleg,
    case 
        when sum(p.amount) > (select avg(ti.monthly_subscription) from tariff_informations ti) then 'Yüksək'
        when sum(p.amount) < (select avg(ti.monthly_subscription) from tariff_informations ti) then 'Aşağı'
        else 'Bərabər'
    end as tarif_ortalama_ile_muqayise
from subscribers su
left join payments p
  on su.subscribers_id = p.subscribers_id
group by su.name, su.surname
order by su.name, su.surname;



 -- 2 ci üsul: Hər bir abonentin ödədiyi ümumi məbləği onun aid olduğu tariflərin ortalama məbləği ilə müqayisə edir. 

with umumi_mebleg as (
    select 
        s.subscribers_id,
        sum(p.amount) as umumi_mebleg
    from subscribers s
    left join payments p
        on s.subscribers_id = p.subscribers_id
    group by s.subscribers_id
),
abonent_tarif as (
    select distinct
        s.subscribers_id,
        t.tariff_id,
        t.tariff_name
    from subscribers s
    join calls c
        on s.subscribers_id = c.caller_id
    join services ser
        on c.service_id = ser.service_id
    join tariff_informations t
        on ser.tariff_id = t.tariff_id
),
ortalama_tarif as (
    select 
        t.tariff_id,
        t.tariff_name,
        avg(p.amount) as ortalama_tarif
    from payments p
    join subscribers s
        on s.subscribers_id = p.subscribers_id
    join calls c
        on c.caller_id = s.subscribers_id
    join services ser
        on c.service_id = ser.service_id
    join tariff_informations t
        on ser.tariff_id = t.tariff_id
    group by t.tariff_id, t.tariff_name
)
select 
    s.name,
    s.surname,
    nvl(m.umumi_mebleg, 0) as umumi_mebleg,
    nvl(o.ortalama_tarif, 0) as ortalama_tarif,
    nvl(a.tariff_name,'None') as tarif_adi,
    case 
        when nvl(m.umumi_mebleg, 0) > nvl(o.ortalama_tarif, 0) then 'Ortalamadan yüksəkdir'
        when nvl(m.umumi_mebleg, 0) < nvl(o.ortalama_tarif, 0) then 'Ortalamadan kiçikdir'
        else 'Ortalama ilə eynidir'
    end as muqayise
from subscribers s
left join umumi_mebleg m
    on s.subscribers_id = m.subscribers_id
left join abonent_tarif a
    on s.subscribers_id = a.subscribers_id
left join ortalama_tarif o
    on a.tariff_id = o.tariff_id
order by s.name, s.surname;








   
       
-- 18. Hər abonentin zənglərin ümumi müddətini və onların zəng müddətinin abonentin yaş qrupunun ortalama zəng müddətindən 
--     yüksək olub olmadığını göstərən sorğu:             
   
-- 1 ci üsul: with istifadə etmədən, eyni zamanda bütün abonentləri ekranda göstərən sorğu

     
select 
    su.name,
    su.surname,
    trunc(months_between(sysdate, su.birth_date)/12) as yas,
    case 
        when trunc(months_between(sysdate, su.birth_date)/12) <= 18 then '18 və aşağı'
        when trunc(months_between(sysdate, su.birth_date)/12) between 19 and 30 then '19-30'
        when trunc(months_between(sysdate, su.birth_date)/12) between 31 and 50 then '31-50'
        else '51 və yuxarı'
    end as yas_qrupu,
    nvl(sum(c.call_duration), 0) as umumi_zeng_muddeti,
    round(
        avg(sum(c.call_duration)) over (
            partition by 
                case 
                    when trunc(months_between(sysdate, su.birth_date)/12) <= 18 then '18 və aşağı'
                    when trunc(months_between(sysdate, su.birth_date)/12) between 19 and 30 then '19-30'
                    when trunc(months_between(sysdate, su.birth_date)/12) between 31 and 50 then '31-50'
                    else '51 və yuxarı'
                end
        ), 
        2
    ) as yas_qrupu_ortalama,
    case 
        when sum(c.call_duration) > avg(sum(c.call_duration)) over (
                partition by 
                    case 
                        when trunc(months_between(sysdate, su.birth_date)/12) <= 18 then '18 və aşağı'
                        when trunc(months_between(sysdate, su.birth_date)/12) between 19 and 30 then '19-30'
                        when trunc(months_between(sysdate, su.birth_date)/12) between 31 and 50 then '31-50'
                        else '51 və yuxarı'
                    end
            )
        then 'Yüksək'
        else 'Aşağı və ya bərabər'
    end as muqayise
from subscribers su
left join calls c
    on su.subscribers_id = c.caller_id
group by su.name, su.surname, su.birth_date
order by yas_qrupu, su.name, su.surname;


-- 2 ci üsul : with ilə eyni zamanda yalnız zəngdən istifadə edən abonentləri ekranda göstərən sorğu


with abonent_zengler as (
    select 
        su.subscribers_id as abonent_id,
        su.name as ad,
        su.surname as soyad,
        trunc(months_between(sysdate, su.birth_date)/12) as yas,
        case 
            when trunc(months_between(sysdate, su.birth_date)/12) <= 18 then '18 və aşağı'
            when trunc(months_between(sysdate, su.birth_date)/12) between 19 and 30 then '19-30'
            when trunc(months_between(sysdate, su.birth_date)/12) between 31 and 50 then '31-50'
            else '51 və yuxarı'
        end as yas_qrupu,
        sum(c.call_duration) as umumi_zeng_muddeti
    from subscribers su
    join calls c
      on su.subscribers_id = c.caller_id
    group by su.subscribers_id, su.name, su.surname, su.birth_date
),
yas_qrupu_ortalama as (
    select
        az.*,
        round(avg(az.umumi_zeng_muddeti) over (partition by az.yas_qrupu), 2) as yas_qrupu_ortalama
    from abonent_zengler az
)
select
    yq.ad,
    yq.soyad,
    yq.yas,
    yq.yas_qrupu,
    yq.umumi_zeng_muddeti,
    yq.yas_qrupu_ortalama,
    case 
        when yq.umumi_zeng_muddeti > yq.yas_qrupu_ortalama then 'Yüksək'
        when yq.umumi_zeng_muddeti < yq.yas_qrupu_ortalama then 'Aşağı'
        else 'Bərabər'
    end as muqayise
from yas_qrupu_ortalama yq
order by yq.yas_qrupu, yq.ad, yq.soyad;






