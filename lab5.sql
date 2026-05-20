USE airport_db;


-- ОПИС КОРИСТУВАЧІВ ТА ЇХ ТИПОВІ ЗАДАЧІ

-- 1. dispatcher  — диспетчер аеропорту
--    Задачі: переглядати розклад рейсів, додавати/змінювати рейси,
--    призначати екіпаж на рейси, переглядати дані про літаки
--
-- 2. pilot_user  — пілот
--    Задачі: переглядати свій розклад, переглядати дані про рейси
--    та літаки, переглядати свої ліцензії
--
-- 3. hr_manager  — HR-менеджер
--    Задачі: додавати/змінювати/видаляти членів екіпажу,
--    керувати ліцензіями пілотів, переглядати всі таблиці
--
-- 4. analyst     — аналітик
--    Задачі: лише читання всіх таблиць для побудови звітів,
--    без права змінювати будь-які дані



-- СТВОРЕННЯ КОРИСТУВАЧІВ


DROP USER IF EXISTS 'dispatcher'@'localhost';
DROP USER IF EXISTS 'pilot_user'@'localhost';
DROP USER IF EXISTS 'hr_manager'@'localhost';
DROP USER IF EXISTS 'analyst'@'localhost';

CREATE USER 'dispatcher'@'localhost' IDENTIFIED BY 'Disp@2026';
CREATE USER 'pilot_user'@'localhost' IDENTIFIED BY 'Pilot@2026';
CREATE USER 'hr_manager'@'localhost' IDENTIFIED BY 'Hr@2026';
CREATE USER 'analyst'@'localhost'    IDENTIFIED BY 'Anal@2026';



--ПЕРСОНАЛЬНІ ПРИВІЛЕЇ КОРИСТУВАЧІВ


-- dispatcher: керує рейсами та призначенням екіпажу
GRANT SELECT, INSERT, UPDATE ON airport_db.flights                  TO 'dispatcher'@'localhost';
GRANT SELECT, INSERT, DELETE ON airport_db.flight_crew_assignments  TO 'dispatcher'@'localhost';
GRANT SELECT                 ON airport_db.aircraft                 TO 'dispatcher'@'localhost';
GRANT SELECT                 ON airport_db.aircraft_models          TO 'dispatcher'@'localhost';
GRANT SELECT                 ON airport_db.crew_members             TO 'dispatcher'@'localhost';

-- pilot_user: лише перегляд свого розкладу та даних
GRANT SELECT ON airport_db.flights                 TO 'pilot_user'@'localhost';
GRANT SELECT ON airport_db.flight_crew_assignments TO 'pilot_user'@'localhost';
GRANT SELECT ON airport_db.aircraft                TO 'pilot_user'@'localhost';
GRANT SELECT ON airport_db.aircraft_models         TO 'pilot_user'@'localhost';
GRANT SELECT ON airport_db.pilot_allowed_models    TO 'pilot_user'@'localhost';

-- hr_manager: повне керування персоналом
GRANT SELECT, INSERT, UPDATE, DELETE ON airport_db.crew_members          TO 'hr_manager'@'localhost';
GRANT SELECT, INSERT, DELETE         ON airport_db.pilot_allowed_models  TO 'hr_manager'@'localhost';
GRANT SELECT                         ON airport_db.flights               TO 'hr_manager'@'localhost';
GRANT SELECT                         ON airport_db.flight_crew_assignments TO 'hr_manager'@'localhost';

-- analyst: лише читання всього
GRANT SELECT ON airport_db.flights                 TO 'analyst'@'localhost';
GRANT SELECT ON airport_db.flight_crew_assignments TO 'analyst'@'localhost';
GRANT SELECT ON airport_db.aircraft                TO 'analyst'@'localhost';
GRANT SELECT ON airport_db.aircraft_models         TO 'analyst'@'localhost';
GRANT SELECT ON airport_db.crew_members            TO 'analyst'@'localhost';
GRANT SELECT ON airport_db.pilot_allowed_models    TO 'analyst'@'localhost';

FLUSH PRIVILEGES;



-- ОПИС РОЛЕЙ

-- 1. role_flight_manager
--    Задачі ролі: повне керування рейсами — додавання, зміна,
--    скасування рейсів, перегляд літаків та екіпажу
--
-- 2. role_readonly
--    Задачі ролі: лише перегляд усіх таблиць БД —
--    для звітності, аналізу, аудиту
--
-- 3. role_crew_manager
--    Задачі ролі: керування складом екіпажу та ліцензіями —
--    додавання пілотів, видача та відкликання допусків до моделей



--  СТВОРЕННЯ РОЛЕЙ ТА ЇХ ПРИВІЛЕЇ


DROP ROLE IF EXISTS 'role_flight_manager';
DROP ROLE IF EXISTS 'role_readonly';
DROP ROLE IF EXISTS 'role_crew_manager';

CREATE ROLE 'role_flight_manager';
CREATE ROLE 'role_readonly';
CREATE ROLE 'role_crew_manager';

-- role_flight_manager
GRANT SELECT, INSERT, UPDATE, DELETE ON airport_db.flights                 TO 'role_flight_manager';
GRANT SELECT, INSERT, DELETE         ON airport_db.flight_crew_assignments TO 'role_flight_manager';
GRANT SELECT                         ON airport_db.aircraft                TO 'role_flight_manager';
GRANT SELECT                         ON airport_db.aircraft_models         TO 'role_flight_manager';
GRANT SELECT                         ON airport_db.crew_members            TO 'role_flight_manager';

-- role_readonly
GRANT SELECT ON airport_db.flights                 TO 'role_readonly';
GRANT SELECT ON airport_db.flight_crew_assignments TO 'role_readonly';
GRANT SELECT ON airport_db.aircraft                TO 'role_readonly';
GRANT SELECT ON airport_db.aircraft_models         TO 'role_readonly';
GRANT SELECT ON airport_db.crew_members            TO 'role_readonly';
GRANT SELECT ON airport_db.pilot_allowed_models    TO 'role_readonly';

-- role_crew_manager
GRANT SELECT, INSERT, UPDATE, DELETE ON airport_db.crew_members         TO 'role_crew_manager';
GRANT SELECT, INSERT, DELETE         ON airport_db.pilot_allowed_models TO 'role_crew_manager';
GRANT SELECT                         ON airport_db.flights              TO 'role_crew_manager';



-- ПРИЗНАЧЕННЯ РОЛЕЙ КОРИСТУВАЧАМ


-- dispatcher отримує роль менеджера рейсів
GRANT 'role_flight_manager' TO 'dispatcher'@'localhost';

-- pilot_user отримує роль лише читання
GRANT 'role_readonly' TO 'pilot_user'@'localhost';

-- hr_manager отримує роль менеджера екіпажу
GRANT 'role_crew_manager' TO 'hr_manager'@'localhost';

-- analyst отримує роль лише читання
GRANT 'role_readonly' TO 'analyst'@'localhost';

FLUSH PRIVILEGES;

-- Перевірка призначених ролей
SELECT user, host FROM mysql.user WHERE user IN ('dispatcher','pilot_user','hr_manager','analyst');
SHOW GRANTS FOR 'dispatcher'@'localhost';
SHOW GRANTS FOR 'analyst'@'localhost';



--ВІДКЛИКАТИ ПЕРСОНАЛЬНИЙ ПРИВІЛЕЙ


-- analyst має SELECT на flights персонально І через role_readonly
-- Відкликаємо персональний SELECT на flights
REVOKE SELECT ON airport_db.flights FROM 'analyst'@'localhost';

-- Перевіряємо гранти — SELECT на flights залишається через роль
SHOW GRANTS FOR 'analyst'@'localhost';

-- Щоб роль була активна за замовчуванням:
SET DEFAULT ROLE 'role_readonly' TO 'analyst'@'localhost';



-- ВІДКЛИКАТИ РОЛЬ у користувача
-- Перевірити що персональні привілеї збереглись а привілеї що були ЛИШЕ через роль — зникли

REVOKE 'role_readonly' FROM 'pilot_user'@'localhost';

--персональні SELECT збереглись, crew_members — зник
SHOW GRANTS FOR 'pilot_user'@'localhost';

-- ВИДАЛИТИ РОЛЬ ТА КОРИСТУВАЧА

DROP ROLE IF EXISTS 'role_readonly';

--analyst втратив привілеї ролі
SHOW GRANTS FOR 'analyst'@'localhost';

-- Видаляємо користувача analyst
DROP USER IF EXISTS 'analyst'@'localhost';

-- Фінальна перевірка — analyst більше не існує
SELECT user, host 
FROM mysql.user 
WHERE user IN ('dispatcher','pilot_user','hr_manager','analyst');
