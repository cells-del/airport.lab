USE airport_db;


-- додати поля UCR, DCR, ULC, DLC до всіх таблиць


ALTER TABLE aircraft_models
    ADD COLUMN UCR VARCHAR(100) DEFAULT NULL,
    ADD COLUMN DCR DATETIME    DEFAULT NULL,
    ADD COLUMN ULC VARCHAR(100) DEFAULT NULL,
    ADD COLUMN DLC DATETIME    DEFAULT NULL;

ALTER TABLE aircraft
    ADD COLUMN UCR VARCHAR(100) DEFAULT NULL,
    ADD COLUMN DCR DATETIME    DEFAULT NULL,
    ADD COLUMN ULC VARCHAR(100) DEFAULT NULL,
    ADD COLUMN DLC DATETIME    DEFAULT NULL;

ALTER TABLE crew_members
    ADD COLUMN UCR VARCHAR(100) DEFAULT NULL,
    ADD COLUMN DCR DATETIME    DEFAULT NULL,
    ADD COLUMN ULC VARCHAR(100) DEFAULT NULL,
    ADD COLUMN DLC DATETIME    DEFAULT NULL;

ALTER TABLE pilot_allowed_models
    ADD COLUMN UCR VARCHAR(100) DEFAULT NULL,
    ADD COLUMN DCR DATETIME    DEFAULT NULL,
    ADD COLUMN ULC VARCHAR(100) DEFAULT NULL,
    ADD COLUMN DLC DATETIME    DEFAULT NULL;

ALTER TABLE flights
    ADD COLUMN UCR VARCHAR(100) DEFAULT NULL,
    ADD COLUMN DCR DATETIME    DEFAULT NULL,
    ADD COLUMN ULC VARCHAR(100) DEFAULT NULL,
    ADD COLUMN DLC DATETIME    DEFAULT NULL;

ALTER TABLE flight_crew_assignments
    ADD COLUMN UCR VARCHAR(100) DEFAULT NULL,
    ADD COLUMN DCR DATETIME    DEFAULT NULL,
    ADD COLUMN ULC VARCHAR(100) DEFAULT NULL,
    ADD COLUMN DLC DATETIME    DEFAULT NULL;



-- ТРИГЕРИ UCR/DCR/ULC/DLC для кожної таблиці


-- aircraft_models
DROP TRIGGER IF EXISTS trg_aircraft_models_insert;
DROP TRIGGER IF EXISTS trg_aircraft_models_update;

DELIMITER $$

CREATE TRIGGER trg_aircraft_models_insert
BEFORE INSERT ON aircraft_models
FOR EACH ROW
BEGIN
    SET NEW.UCR = USER();
    SET NEW.DCR = NOW();
    SET NEW.ULC = USER();
    SET NEW.DLC = NOW();
END$$

CREATE TRIGGER trg_aircraft_models_update
BEFORE UPDATE ON aircraft_models
FOR EACH ROW
BEGIN
    SET NEW.ULC = USER();
    SET NEW.DLC = NOW();
END$$

DELIMITER ;

-- aircraft
DROP TRIGGER IF EXISTS trg_aircraft_insert;
DROP TRIGGER IF EXISTS trg_aircraft_update;

DELIMITER $$

CREATE TRIGGER trg_aircraft_insert
BEFORE INSERT ON aircraft
FOR EACH ROW
BEGIN
    SET NEW.UCR = USER();
    SET NEW.DCR = NOW();
    SET NEW.ULC = USER();
    SET NEW.DLC = NOW();
END$$

CREATE TRIGGER trg_aircraft_update
BEFORE UPDATE ON aircraft
FOR EACH ROW
BEGIN
    SET NEW.ULC = USER();
    SET NEW.DLC = NOW();
END$$

DELIMITER ;

-- crew_members
DROP TRIGGER IF EXISTS trg_crew_members_insert;
DROP TRIGGER IF EXISTS trg_crew_members_update;

DELIMITER $$

CREATE TRIGGER trg_crew_members_insert
BEFORE INSERT ON crew_members
FOR EACH ROW
BEGIN
    SET NEW.UCR = USER();
    SET NEW.DCR = NOW();
    SET NEW.ULC = USER();
    SET NEW.DLC = NOW();
END$$

CREATE TRIGGER trg_crew_members_update
BEFORE UPDATE ON crew_members
FOR EACH ROW
BEGIN
    SET NEW.ULC = USER();
    SET NEW.DLC = NOW();
END$$

DELIMITER ;

-- pilot_allowed_models
DROP TRIGGER IF EXISTS trg_pilot_allowed_insert;
DROP TRIGGER IF EXISTS trg_pilot_allowed_update;

DELIMITER $$

CREATE TRIGGER trg_pilot_allowed_insert
BEFORE INSERT ON pilot_allowed_models
FOR EACH ROW
BEGIN
    SET NEW.UCR = USER();
    SET NEW.DCR = NOW();
    SET NEW.ULC = USER();
    SET NEW.DLC = NOW();
END$$

CREATE TRIGGER trg_pilot_allowed_update
BEFORE UPDATE ON pilot_allowed_models
FOR EACH ROW
BEGIN
    SET NEW.ULC = USER();
    SET NEW.DLC = NOW();
END$$

DELIMITER ;

-- flights
DROP TRIGGER IF EXISTS trg_flights_insert;
DROP TRIGGER IF EXISTS trg_flights_update;

DELIMITER $$

CREATE TRIGGER trg_flights_insert
BEFORE INSERT ON flights
FOR EACH ROW
BEGIN
    SET NEW.UCR = USER();
    SET NEW.DCR = NOW();
    SET NEW.ULC = USER();
    SET NEW.DLC = NOW();
END$$

CREATE TRIGGER trg_flights_update
BEFORE UPDATE ON flights
FOR EACH ROW
BEGIN
    SET NEW.ULC = USER();
    SET NEW.DLC = NOW();
END$$

DELIMITER ;

-- flight_crew_assignments
DROP TRIGGER IF EXISTS trg_fca_insert;
DROP TRIGGER IF EXISTS trg_fca_update;

DELIMITER $$

CREATE TRIGGER trg_fca_insert
BEFORE INSERT ON flight_crew_assignments
FOR EACH ROW
BEGIN
    SET NEW.UCR = USER();
    SET NEW.DCR = NOW();
    SET NEW.ULC = USER();
    SET NEW.DLC = NOW();
END$$

CREATE TRIGGER trg_fca_update
BEFORE UPDATE ON flight_crew_assignments
FOR EACH ROW
BEGIN
    SET NEW.ULC = USER();
    SET NEW.DLC = NOW();
END$$

DELIMITER ;


-- сурогатний ключ для flight_crew_assignments. Таблиця має композитний PK — додамо surrogate id
-- та тригер для автозаповнення послідовними значеннями


ALTER TABLE flight_crew_assignments
    ADD COLUMN assignment_id INT DEFAULT NULL;

-- Допоміжна таблиця-лічильник (вирішує проблему mutating table)
DROP TABLE IF EXISTS fca_sequence;
CREATE TABLE fca_sequence (
    id INT PRIMARY KEY DEFAULT 1,
    next_val INT DEFAULT 1
);
INSERT INTO fca_sequence VALUES (1, 1);

DROP TRIGGER IF EXISTS trg_fca_surrogate_key;

DELIMITER $$

CREATE TRIGGER trg_fca_surrogate_key
BEFORE INSERT ON flight_crew_assignments
FOR EACH ROW
BEGIN
    DECLARE v_next INT;

    -- Читаємо поточне значення лічильника
    SELECT next_val INTO v_next FROM fca_sequence WHERE id = 1;

    -- Заповнюємо сурогатний ключ
    SET NEW.assignment_id = v_next;

    -- Збільшуємо лічильник
    UPDATE fca_sequence SET next_val = v_next + 1 WHERE id = 1;
END$$

DELIMITER ;


--тригери перевірки цілісності

-- Допоміжна таблиця для перевірки (уникаємо mutating table)
DROP TABLE IF EXISTS crew_schedule_check;
CREATE TABLE crew_schedule_check (
    member_id   INT NOT NULL,
    flight_id   INT NOT NULL,
    dep_time    DATETIME NOT NULL,
    land_time   DATETIME NOT NULL
);

-- Заповнюємо допоміжну таблицю поточними даними
INSERT INTO crew_schedule_check (member_id, flight_id, dep_time, land_time)
SELECT
    fca.member_id,
    fca.flight_id,
    f.departure_time,
    f.landing_time
FROM flight_crew_assignments fca
JOIN flights f ON fca.flight_id = f.flight_id;

-- Синхронізуємо допоміжну таблицю при додаванні призначення
DROP TRIGGER IF EXISTS trg_fca_sync_schedule;

DELIMITER $$

CREATE TRIGGER trg_fca_sync_schedule
AFTER INSERT ON flight_crew_assignments
FOR EACH ROW
BEGIN
    DECLARE v_dep  DATETIME;
    DECLARE v_land DATETIME;

    SELECT departure_time, landing_time
    INTO   v_dep, v_land
    FROM   flights
    WHERE  flight_id = NEW.flight_id;

    INSERT INTO crew_schedule_check (member_id, flight_id, dep_time, land_time)
    VALUES (NEW.member_id, NEW.flight_id, v_dep, v_land);
END$$

DELIMITER ;


-- перерва між вильотами не менше 3 днів
DROP TRIGGER IF EXISTS trg_check_pilot_rest;

DELIMITER $$

CREATE TRIGGER trg_check_pilot_rest
BEFORE INSERT ON flight_crew_assignments
FOR EACH ROW
BEGIN
    DECLARE v_dep_new   DATETIME;
    DECLARE v_land_new  DATETIME;
    DECLARE v_conflict  INT DEFAULT 0;

    -- Отримуємо час нового рейсу
    SELECT departure_time, landing_time
    INTO   v_dep_new, v_land_new
    FROM   flights
    WHERE  flight_id = NEW.flight_id;

    -- Перевіряємо через допоміжну таблицю (не mutating)
    -- чи є рейси цього члена екіпажу в межах 3 днів
    SELECT COUNT(*) INTO v_conflict
    FROM crew_schedule_check
    WHERE member_id = NEW.member_id
      AND (
          -- новий рейс надто близько до існуючого
          ABS(TIMESTAMPDIFF(HOUR, dep_time, v_dep_new)) < 72
      );

    IF v_conflict > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Помилка: пілот повинен мати перерву між вильотами не менше 3 днів!';
    END IF;
END$$

DELIMITER ;


-- заборона одночасного призначення на кілька рейсів
DROP TRIGGER IF EXISTS trg_check_crew_conflict;

DELIMITER $$

CREATE TRIGGER trg_check_crew_conflict
BEFORE INSERT ON flight_crew_assignments
FOR EACH ROW
BEGIN
    DECLARE v_dep_new   DATETIME;
    DECLARE v_land_new  DATETIME;
    DECLARE v_conflict  INT DEFAULT 0;

    -- Час нового рейсу
    SELECT departure_time, landing_time
    INTO   v_dep_new, v_land_new
    FROM   flights
    WHERE  flight_id = NEW.flight_id;

    -- Перевіряємо перетин часових інтервалів через допоміжну таблицю
    SELECT COUNT(*) INTO v_conflict
    FROM crew_schedule_check
    WHERE member_id = NEW.member_id
      AND flight_id <> NEW.flight_id
      AND dep_time  < v_land_new
      AND land_time > v_dep_new;

    IF v_conflict > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Помилка: член екіпажу вже призначений на інший рейс у цей час!';
    END IF;
END$$

DELIMITER ;

-- тест тригерів

-- Перевірка UCR/DCR — вставляємо нову модель
INSERT INTO aircraft_models (model_name, seats_count, payload_capacity)
VALUES ('Boeing 777', 300, 8000);

SELECT model_name, UCR, DCR, ULC, DLC
FROM aircraft_models
WHERE model_name = 'Boeing 777';

-- Перевірка сурогатного ключа
SELECT * FROM flight_crew_assignments;

-- Тест конфлікту розкладу (має дати помилку):
INSERT INTO flight_crew_assignments (flight_id, member_id)
VALUES (2, 3);
