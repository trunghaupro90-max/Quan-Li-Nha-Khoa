-- CHAY SAU KHI TAO USER TRONG SUPABASE AUTH > USERS
-- 1) Gan ADMIN TONG:
update public.profiles set username='admin', role='super_admin', clinic_id=null, active=true
where id=(select id from auth.users where email='admin@login.nhakhoa.local');

-- 2) Gan tung tai khoan chi nhanh (chay tung cau sau khi da tao user):
update public.profiles set username='cn1', role='branch_admin', clinic_id=(select id from public.clinics where code='CN1'), active=true
where id=(select id from auth.users where email='cn1@login.nhakhoa.local');

update public.profiles set username='cn2', role='branch_admin', clinic_id=(select id from public.clinics where code='CN2'), active=true
where id=(select id from auth.users where email='cn2@login.nhakhoa.local');

update public.profiles set username='cn3', role='branch_admin', clinic_id=(select id from public.clinics where code='CN3'), active=true
where id=(select id from auth.users where email='cn3@login.nhakhoa.local');

update public.profiles set username='cn4', role='branch_admin', clinic_id=(select id from public.clinics where code='CN4'), active=true
where id=(select id from auth.users where email='cn4@login.nhakhoa.local');

update public.profiles set username='cn5', role='branch_admin', clinic_id=(select id from public.clinics where code='CN5'), active=true
where id=(select id from auth.users where email='cn5@login.nhakhoa.local');

update public.profiles set username='cn6', role='branch_admin', clinic_id=(select id from public.clinics where code='CN6'), active=true
where id=(select id from auth.users where email='cn6@login.nhakhoa.local');

-- Doi ten chi nhanh theo ten that:
-- update public.clinics set name='Ten chi nhanh' where code='CN1';

-- TEN CHINH THUC 6 CHI NHANH (co the chay rieng neu da tao bang clinics):
update public.clinics set name='Nha Khoa Việt Đức Phú Hoà' where code='CN1';
update public.clinics set name='Nha Khoa Việt Đức Núi Sập' where code='CN2';
update public.clinics set name='Nha Khoa Việt Đức Óc Eo' where code='CN3';
update public.clinics set name='Nha Khoa Việt Đức Châu Phú' where code='CN4';
update public.clinics set name='Nha Khoa Việt Đức Mỹ Luông' where code='CN5';
update public.clinics set name='Nha Khoa Tâm An' where code='CN6';
