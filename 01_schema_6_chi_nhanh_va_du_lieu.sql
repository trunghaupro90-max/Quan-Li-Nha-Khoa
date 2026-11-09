
-- NHA KHOA 6 CHI NHANH - Supabase SQL
create extension if not exists pgcrypto;

create table if not exists public.clinics (
 id uuid primary key default gen_random_uuid(),
 code text unique not null,
 name text not null,
 active boolean not null default true,
 created_at timestamptz not null default now()
);

insert into public.clinics(code,name) values
 ('CN1','Nha Khoa Việt Đức Phú Hoà'),
 ('CN2','Nha Khoa Việt Đức Núi Sập'),
 ('CN3','Nha Khoa Việt Đức Óc Eo'),
 ('CN4','Nha Khoa Việt Đức Châu Phú'),
 ('CN5','Nha Khoa Việt Đức Mỹ Luông'),
 ('CN6','Nha Khoa Tâm An')
on conflict (code) do update set name=excluded.name;

create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 username text unique not null,
 role text not null default 'branch_admin' check (role in ('super_admin','branch_admin','branch_staff','pending')),
 clinic_id uuid references public.clinics(id),
 active boolean not null default true,
 created_at timestamptz not null default now(),
 constraint profile_role_branch check (
   (role in ('super_admin','pending') and clinic_id is null) or
   (role in ('branch_admin','branch_staff') and clinic_id is not null)
 )
);

create table if not exists public.clinic_sheets (
 clinic_id uuid not null references public.clinics(id) on delete cascade,
 sheet_key text not null,
 payload jsonb not null,
 updated_at timestamptz not null default now(),
 updated_by uuid references auth.users(id),
 primary key(clinic_id,sheet_key)
);

create or replace function public.my_role()
returns text language sql stable security definer set search_path=public
as $$ select role from public.profiles where id=auth.uid() and active=true $$;

create or replace function public.my_clinic_id()
returns uuid language sql stable security definer set search_path=public
as $$ select clinic_id from public.profiles where id=auth.uid() and active=true $$;

alter table public.clinics enable row level security;
alter table public.profiles enable row level security;
alter table public.clinic_sheets enable row level security;

drop policy if exists "clinic visibility" on public.clinics;
create policy "clinic visibility" on public.clinics for select to authenticated
using (public.my_role()='super_admin' or id=public.my_clinic_id());

drop policy if exists "admin manage clinics" on public.clinics;
create policy "admin manage clinics" on public.clinics for all to authenticated
using (public.my_role()='super_admin') with check (public.my_role()='super_admin');

drop policy if exists "profile self or superadmin" on public.profiles;
create policy "profile self or superadmin" on public.profiles for select to authenticated
using (id=auth.uid() or public.my_role()='super_admin');

drop policy if exists "superadmin manage profiles" on public.profiles;
create policy "superadmin manage profiles" on public.profiles for all to authenticated
using (public.my_role()='super_admin') with check (public.my_role()='super_admin');

drop policy if exists "read own clinic or all as admin" on public.clinic_sheets;
create policy "read own clinic or all as admin" on public.clinic_sheets for select to authenticated
using (public.my_role()='super_admin' or clinic_id=public.my_clinic_id());

drop policy if exists "write own clinic or all as admin" on public.clinic_sheets;
create policy "write own clinic or all as admin" on public.clinic_sheets for insert to authenticated
with check (public.my_role()='super_admin' or clinic_id=public.my_clinic_id());

drop policy if exists "update own clinic or all as admin" on public.clinic_sheets;
create policy "update own clinic or all as admin" on public.clinic_sheets for update to authenticated
using (public.my_role()='super_admin' or clinic_id=public.my_clinic_id())
with check (public.my_role()='super_admin' or clinic_id=public.my_clinic_id());

drop policy if exists "delete own branch or all as admin" on public.clinic_sheets;
create policy "delete own branch or all as admin" on public.clinic_sheets for delete to authenticated
using (public.my_role()='super_admin' or (public.my_role()='branch_admin' and clinic_id=public.my_clinic_id()));

-- Auto-create profile for each Auth user. Metadata can select a branch code, never a role.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public
as $$
declare v_clinic uuid; v_username text;
begin
 v_username := lower(coalesce(new.raw_user_meta_data->>'username', split_part(new.email,'@',1)));
 select id into v_clinic from public.clinics
 where code=upper(coalesce(new.raw_user_meta_data->>'branch_code','')) and active=true;
 insert into public.profiles(id,username,role,clinic_id)
 values(new.id,v_username,case when v_clinic is null then 'pending' else 'branch_admin' end,v_clinic)
 on conflict (id) do nothing;
 return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Enable realtime notifications for cross-device updates.
do $$ begin
 alter publication supabase_realtime add table public.clinic_sheets;
exception when duplicate_object then null; when others then null;
end $$;

-- Import the supplied Excel workbook into CN1 only.

insert into public.clinic_sheets(clinic_id,sheet_key,payload)
select id,'VĐ2','{"headers":["Ngày","SĐT","Tên khách hàng","Dịch vụ / Nội dung","Tổng tiền","Đã thu","Còn nợ","Ghi chú"],"rows":[["DANH SÁCH KHÁCH HÀNG VIỆT ĐỨC 2 THÁNG 11/2026","","","","","","",""],["2026-11-01","","A","NEB",380,380,0,""],["","","B","TR 5R",1000,1000,0,""],["","","C","CV 3",750,750,0,""],["","","D","TR + N",650,650,0,""],["","","E","GẮN KEO",400,400,0,""],["","","ANH LỢI","ĐÍNH ĐÁ + CV",950,950,0,""],["",907949735,"LÊ THỊ BÉ SÁU","PHTL 13R 300 + MCLD 1R 1100 + N + LƯỚI",5500,2500,3000,""],["",383093024,"LÊ THỊ MẢNH","PHTL 14R 450 + MCLD 14R 1100 + NHỰA DẺO (GIẢM 2500)",22000,7000,15000,""],["",362166503,"BÍCH LỢI","MCLD 6R 2500 + N (GIẢM 600)",14600,5000,9600,""],["","","CHÚ KHÍCH","GR","",2000,0,""],["","","","","","","TT: 20630",""],["","","","","","","CHI: 6327",""],["","","","","","","CL: 14303",""],["2026-11-02","","A","NRC",1300,1300,0,""],["","","CHÚ TRÍ","ĐTT 2R",1600,300,1300,""],["","","ĐINH THỊ KIM TIẾN","ĐÍNH ĐÁ",700,700,0,""],["","","B","N",600,600,0,""],["","","C","NEB",30,30,0,""],["","","CHỊ BÍCH","GR","",10000,0,""],["","","TUYẾT NHI","GR + N",200,4900,0,""],["","","","","","","TT: 17830",""],["","","","","","","CHI: 780",""],["","","","","","","CL: 17050",""],["2026-11-03","","A","NEB",30,30,0,""],["","","B","CV",300,300,0,""],["",374018768,"VÕ THỊ DUYÊN","MCLD 1R 1100 + CV + TR",1650,1150,500,""],["","","","","","","TT: 1480",""],["","","","","","","CHI: 144",""],["","","","","","","CL: 1336",""],["2026-11-04",368969328,"ANH ÚT EM","MCLD 2R 2900",5800,3000,2800,""],["",398037955,"CAO HỮU MỘNG","MCLD 13R 1100 (GIẢM 1300)",13000,3000,10000,""],["","","A","TR",300,300,0,""],["","","B","NRC",1800,1800,0,""],["","","LÊ THỊ MẢNH","CỌC THÊM","",12000,3000,""],["","","","","","","TT: 20100",""],["","","","","","","CHI: 3330",""],["","","","","","","CL: 16770",""],["2026-11-05",375489553,"NGUYỄN THANH LỢI","MCLD 5R 1100",5500,3000,2500,""],["","","A","NEB",30,30,0,""],["","","KHANG","ĐTT",900,900,0,""],["",946633554,"CHÚ TRÍ","MCLD 3R 1100 + THU ĐỦ PHẦN CŨ",3300,2000,2600,""],["","","BÍCH LỢI","GR","",9600,0,""],["","","","","","","TT: 15530",""],["","","","","","","CHI: 1525",""],["","","","","","","CL: 14005",""],["2026-11-06","","TRẦN THỊ OANH","ĐTT",800,800,0,""],["","","A","CV",250,250,0,""],["","","ANH ÚT EM","GR","",2800,0,""],["","","CAO HỮU MỘNG","","",10000,0,""],["","","LÊ THỊ MẢNH","","",3000,0,""],["","","","","","","TT: 16850",""],["","","","","","","CHI: 228",""],["","","","","","","CL: 16622",""],["2026-11-07","","A","NEB",210,210,0,""],["","","B","N 3R",600,600,0,""],["","","C","CV + GẮN KEO",800,800,0,""],["","","DƯƠNG NGỌC QUỲNH ANH","ĐTT",700,700,0,""],["",336822061,"TUYẾT NHI","MCLD 3R 2900 + N (GIẢM 300)",9000,1000,8000,""],["","","NGUYỄN TUẤN KIỆT","ĐTT",800,800,0,""],["","","NGUYỄN THANH LỢI","GR","",2500,0,""],["","","CHÚ TRÍ","GR","",2600,0,""],["","","","","","","TT: 9210",""],["","","","","","","CHI: 1650",""],["","","","","","","CL: 7560",""],["2026-11-08","","A","NEB",120,120,0,""],["","","NGUYỄN THỊ MIỀU","HÀN",300,300,0,""],["",333434745,"LƯU VĂN HƯỜNG","MCLD 10R 1100",11000,4000,7000,""],["",984015489,"TRƯƠNG VĂN THOẠI","MCLD 4R 1100 + TR3R",5150,3000,2150,""],["",329166334,"PHAN VĂN THẶT ","MCLD 7R 1100 + TR2R + CVR",8550,4050,4500,""],["",946277604,"LÝ TÔ NGUYỆT","MCLD 4R 1100 + BH 1R SKL + TRÁM TẠM",4600,2000,2600,""],["",374677400,"EM QUÝ","MCLD 1R 2900 + ĐTT 800",3700,2000,1700,""],["","","B","GẮN KEO",200,200,0,""],["","","C","TR",250,250,0,""],["",982678052,"NGUYỄN THỊ DIỄM","MCLD 12R 2900 ",34800,10000,24800,""],["","","","","","","TT 25920",""],["","","","","","","CHI 7916",""],["","","","","","","CL 18004",""]]}'::jsonb from public.clinics where code='CN1'
on conflict (clinic_id,sheet_key) do nothing;

insert into public.clinic_sheets(clinic_id,sheet_key,payload)
select id,'DS CHƯA GR','{"headers":["Ngày","SĐT","Tên khách hàng","Dịch vụ / Nội dung","Tổng tiền","Đã thu","Còn nợ","Ghi chú"],"rows":[["2025-03-26",981267543,"CÔ MỌT","MCLD 2R*890",1780,500,1280,""],["2025-04-02","","CON CHỊ HIỀN","CỌC KHUYẾN MÃI 14R*1120 (ĐÃ GIẢM RỒI)",15700,6700,9000,""],["",344207989,"CHỊ HOA","MCLD 5R ZICO",10000,3500,6500,""],["",365765746,"CÔ NGUYỄN THỊ BỚT","MCLD 1R 2900 + NRC 2",5500,3500,2000,""],["",966005996,"KIM NGỌC","MCLD 1R 1100",1100,500,600,""],["2025-09-30",337388952,"HUY","MCLD 1R 1800 + CV",2000,1200,800,""],["","","NGUYỄN MINH ANH + TÔ THỊ NGỌC DUNG","ĐTT 2R + MCLD 2R 1100 + CV",3900,1700,2200,""],["",386609804,"LÊ THỊ QUỲNH ANH","MCLD 3R 1100 + ĐTT",3900,2000,1900,""],["2025-11-18",383581719,"NGỌC LỤA","MCLD 12R 700 + N + LÀM THÊM 2R 700 + PHTL 12R 390 + N + NHỰA DẺO (GIẢM 300)",26560,24560,2000,""],["2025-11-25",383581719,"PHAN THỊ PHẢI","MCLD 2R 700 + PHTL 26R 290 (GIẢM 860)","","","",""],["",388829236,"NGÔ VĂN CÓ","MCLD 1R 2900 + CV + ĐTT",3950,1500,2450,""],["",368490369,"CHÚ THIẾU","PHTL 14R 300 + LƯỚI + HÀN HÀM",4700,4700,0,""],["",988230026,"CHÚ KHÍCH","MCLD 2R 1500",3000,1000,2000,""],["",359266169,"CHỊ BÍCH","MCLD 4R 2900 + 2R 2500 + TR 4R (GIẢM 600)",17000,7000,10000,""],["",336822061,"TUYẾT NHI","MCLD 3R 2900",8700,4000,4700,""],["2026-11-01",907949735,"LÊ THỊ BÉ SÁU","PHTL 13R 300 + MCLD 1R 1100 + N + LƯỚI",5500,2500,3000,""],["",383093024,"LÊ THỊ MẢNH","PHTL 14R 450 + MCLD 14R 1100 + NHỰA DẺO (GIẢM 2500)",22000,19000,3000,""],["",362166503,"BÍCH LỢI","MCLD 6R 2500 + N (GIẢM 600)",14600,5000,9600,""],["",374018768,"VÕ THỊ DUYÊN","MCLD 1R 1100 + CV + TR",1650,1150,500,""],["2026-11-04",368969328,"ANH ÚT EM","MCLD 2R 2900",5800,3000,2800,""],["",398037955,"CAO HỮU MỘNG","MCLD 13R 1100 (GIẢM 1300)",13000,3000,10000,""],["2026-11-05",375489553,"NGUYỄN THANH LỢI","MCLD 5R 1100",5500,3000,2500,""],["",946633554,"CHÚ TRÍ","MCLD 3R 1100 + THU ĐỦ PHẦN CŨ",3300,2000,2600,""],["",336822061,"TUYẾT NHI","MCLD 3R 2900 + N (GIẢM 300)",9000,1000,8000,""],["2026-11-08",333434745,"LƯU VĂN HƯỜNG","MCLD 10R 1100",11000,4000,7000,""],["",984015489,"TRƯƠNG VĂN THOẠI","MCLD 4R 1100 + TR3R",5150,3000,2150,""],["",329166334,"PHAN VĂN THẶT ","MCLD 7R 1100 + TR2R + CVR",8550,4050,4500,""],["",946277604,"LÝ TÔ NGUYỆT","MCLD 4R 1100 + BH 1R SKL + TRÁM TẠM",4600,2000,2600,""],["",374677400,"EM QUÝ","MCLD 1R 2900 + ĐTT 800",3700,2000,1700,""],["",982678052,"NGUYỄN THỊ DIỄM","MCLD 12R 2900 ",34800,10000,24800,""]]}'::jsonb from public.clinics where code='CN1'
on conflict (clinic_id,sheet_key) do nothing;

insert into public.clinic_sheets(clinic_id,sheet_key,payload)
select id,'LAB','{"headers":["Ngày gửi LAB","Tên khách","SKL","LAVA","ZICO","Thanh trợ lực","","","","Ngày gửi tháo lắp","Tên khách","Số lượng","Nhựa dẻo","HTT","Ghi chú"],"rows":[["LAB THÁNG 11","","","","","","","","","THÁO LẮP VIỆT ĐỨC","","","","",""],["NGÀY GỬI LAB","TÊN","SKL","LAVA","ZICO","THANH TRỢ LỰC","","","","NGÀY GỬI LAB","TÊN","SỐ LƯỢNG","NHỰA DẺO","HTT","GHI CHÚ"]]}'::jsonb from public.clinics where code='CN1'
on conflict (clinic_id,sheet_key) do nothing;

insert into public.clinic_sheets(clinic_id,sheet_key,payload)
select id,'CHI ','{"headers":["Ngày","Nội dung chi","Số tiền","Tổng chi trong ngày"],"rows":[["DANH SÁCH CHI THÁNG 11/2026","","",""],["2026-11-01","GIỎ TRÁI CÂY",400,6327],["","VẬT LIỆU",1050,""],["","BAO TAY",75,""],["","THUỐC",193,""],["","RÁC",30,""],["","METRO 5T",135,""],["","DOLFENAL + BAO TỬ + KHAPARAC",64,""],["","1SKL (SÁU)\n14SKL + NHỰA DẺO (MẢNH)\n6ZICO (LỢI)",4380,""],["2026-11-02","METRO 3T + KHAPARAC 5H",130,780],["","THUỐC + TRÁI CÂY",650,""],["2026-11-03","1SKL (DUYÊN)",144,144],["2026-11-04","THUỐC + VẬT LIỆU",878,3330],["","BỌC + CƯỚC RỬA CHÉN",40,""],["","2ZICO (EM)\n13SKL (MỘNG)",2412,""],["2026-11-05","5SKL (LỢI)\n3SKL (TRÍ)",1152,1525],["","TIỀN NƯỚC",155,""],["","THUỐC",218,""],["2026-11-06","THUỐC",218,476],["","TẠP HOÁ",228,""],["","DOLFENAL",30,""],["2026-11-07","ĐỒ CÚNG",840,1650],["","3ZICO (NHI)",810,""],["2026-11-08","NƯỚC ĐÁ",98,7916],["","VẬT LIỆU",450,""],["","THUỐC",218,""],["","10SKL (HƯỜNG) + 4SKL (THOẠI) + 7SKL (THẶT)",6650,""],["","4SKL + BH1R (NGUYỆT) + 1ZICO (QUÝ) + 10ZICO ( DIỄM)","",""],["","THƯỞNG CLOAN",500,""]]}'::jsonb from public.clinics where code='CN1'
on conflict (clinic_id,sheet_key) do nothing;

insert into public.clinic_sheets(clinic_id,sheet_key,payload)
select id,'LỊCH NGHỈ','{"headers":["Ngày","C Loan","Quỳnh","C Uyên","Nhi","Min","","","","","","","Ngày (bảng phụ)","Ghi chú"],"rows":[["THÁNG 11/2026","","","","","","","","","","","","",""],["NGÀY","C LOAN","QUỲNH","C UYÊN","NHI","MIN","","","","","","","NGÀY",""],["2026-11-01","","","","","","","","","","","","2026-11-01",""],["2026-11-02","","","","","","","","","","","","2026-11-02",""],["2026-11-03","","","","","","","","","","","","2026-11-03",""],["2026-11-04","","","","","","","","","","","","2026-11-04",""],["2026-11-05","","","","","",7,"","","","","","2026-11-05",""],["2026-11-06","","","","","","","","","","","","2026-11-06",""],["2026-11-07","","","","","",7.2,"","","","","","2026-11-07",""],["2026-11-08","","","","1/2C","","","","","","","","2026-11-08",""],["2026-11-09","","","","","","","","","","","","2026-11-09",""],["2026-11-10","","","","","","","","","","","","2026-11-10",""],["2026-11-11","","","","","","","","","","","","2026-11-11",""],["2026-11-12","","","","","","","","","","","","2026-11-12",""],["2026-11-13","","","","","","","","","","","","2026-11-13",""],["2026-11-14","","","","","","","","","","","","2026-11-14",""],["2026-11-15","","","","","","","","","","","","2026-11-15",""],["2026-11-16","","","","","","","","","","","","2026-11-16",""],["2026-11-17","","","","","","","","","","","","2026-11-17",""],["2026-11-18","","","","","","","","","","","","2026-11-18",""],["2026-11-19","","","","","","","","","","","","2026-11-19",""],["2026-11-20","","","","","","","","","","","","2026-11-20",""],["2026-11-21","","","","","","","","","","","","2026-11-21",""],["2026-11-22","","","","","","","","","","","","2026-11-22",""],["2026-11-23","","","","","","","","","","","","2026-11-23",""],["2026-11-24","","","","","","","","","","","","2026-11-24",""],["2026-11-25","","","","","","","","","","","","2026-11-25",""],["2026-11-26","","","","","","","","","","","","2026-11-26",""],["2026-11-27","","","","","","","","","","","","2026-11-27",""],["2026-11-28","","","","","","","","","","","","2026-11-28",""],["2026-11-29","","","","","","","","","","","","2026-11-29",""],["2026-11-30","","","","","","","","","","","","2026-11-30",""]]}'::jsonb from public.clinics where code='CN1'
on conflict (clinic_id,sheet_key) do nothing;

insert into public.clinic_sheets(clinic_id,sheet_key,payload)
select id,'TỔNG KẾT','{"headers":["","Nội dung","SKL","ZICO","Tháo lắp","","HTT","Nhựa dẻo","Thành tiền"],"rows":[["","TỔNG KẾT THÁNG 11","","","","","",""],["","TỔNG THU: ","","","","","",""],["","TỔNG CHI: ","","","","","",""],["","SKL ","ZICO","THÁO LẮP","","HTT","NHỰA DẺO","THÀNH TIỀN"],["",5184,"","","","","",""],["","TỔNG (THU - CHI): ","","","","","",""]]}'::jsonb from public.clinics where code='CN1'
on conflict (clinic_id,sheet_key) do nothing;
