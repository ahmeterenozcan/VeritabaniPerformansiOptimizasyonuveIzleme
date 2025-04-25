-- 1) Veritabanı Oluşturma
CREATE DATABASE PerformansDB;
GO

-- 2) Tablonun Oluşturulması
USE PerformansDB;
GO

CREATE TABLE Siparisler (
    SiparisID INT IDENTITY(1,1) PRIMARY KEY,
    MusteriAdi NVARCHAR(100),
    UrunAdi NVARCHAR(100),
    SiparisTarihi DATE,
    Miktar INT,
    Fiyat MONEY
);

-- 3) Sahte Veri Ekleme (1.000.000 satır)
SET NOCOUNT ON;
DECLARE @i INT = 0;

WHILE @i < 1000000
BEGIN
    INSERT INTO Siparisler (MusteriAdi, UrunAdi, SiparisTarihi, Miktar, Fiyat)
    VALUES (
        'Müşteri_' + CAST(@i AS NVARCHAR),
        'Ürün_' + CAST(@i % 100 AS NVARCHAR),
        DATEADD(DAY, -(@i % 365), GETDATE()),
        ABS(CHECKSUM(NEWID())) % 10 + 1,
        ABS(CHECKSUM(NEWID())) % 500 + 50
    );
    SET @i += 1;
END;

-- 4) Ağır Sorgu (Test için)
SELECT 
    MusteriAdi,
    COUNT(*) AS ToplamSiparis,
    SUM(Miktar) AS ToplamMiktar,
    SUM(Fiyat) AS ToplamTutar
FROM Siparisler
WHERE SiparisTarihi >= '2023-01-01'
GROUP BY MusteriAdi
ORDER BY ToplamTutar DESC;

-- 5) İndeks Oluşturma
CREATE NONCLUSTERED INDEX IX_Siparisler_MusteriTarih 
ON Siparisler (MusteriAdi, SiparisTarihi);

-- 6) Optimize Sorgu Örneği
SELECT TOP 10
    MusteriAdi,
    COUNT(*) AS SiparisSayisi,
    SUM(Miktar * Fiyat) AS ToplamTutar
FROM Siparisler
WHERE SiparisTarihi >= '2023-01-01'
GROUP BY MusteriAdi
ORDER BY ToplamTutar DESC;

-- 7) SQL Profiler için kullanılabilecek sorgu aynıdır (yukarıdaki ağır sorgu)

-- 8) DMV ile Pahalı Sorguları Göster
SELECT TOP 10 
    qs.total_elapsed_time / qs.execution_count AS AvgElapsedTime,
    qs.execution_count,
    qs.total_elapsed_time,
    SUBSTRING(qt.text, qs.statement_start_offset / 2, 
              (CASE WHEN qs.statement_end_offset = -1 
                    THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2 
                    ELSE qs.statement_end_offset END - qs.statement_start_offset) / 2) AS QueryText,
    qt.dbid,
    qt.objectid
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
ORDER BY AvgElapsedTime DESC;

-- 9) Kullanıcı Giriş (Login) Oluşturma
CREATE LOGIN Kullanici_Oku WITH PASSWORD = 'P@ssword123';
CREATE LOGIN Kullanici_Yonetici WITH PASSWORD = 'P@ssword456';

-- 10) Kullanıcıyı Veritabanına Tanıtma
USE PerformansDB;
GO
CREATE USER Kullanici_Oku FOR LOGIN Kullanici_Oku;
CREATE USER Kullanici_Yonetici FOR LOGIN Kullanici_Yonetici;

-- 11) Rol Oluşturma ve Yetki Atama
-- Okuma Yetkili Rol
EXEC sp_addrole 'RaporGoruntuleyici';
GRANT SELECT ON Siparisler TO RaporGoruntuleyici;
EXEC sp_addrolemember 'RaporGoruntuleyici', 'Kullanici_Oku';

-- Tam Yetkili Rol
EXEC sp_addrole 'Yonetici';
GRANT SELECT, INSERT, UPDATE, DELETE ON Siparisler TO Yonetici;
EXEC sp_addrolemember 'Yonetici', 'Kullanici_Yonetici';
