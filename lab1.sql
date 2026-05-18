DROP DATABASE IF EXISTS airport_db;
CREATE DATABASE airport_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE airport_db;

-- 1. Таблиця моделей літаків
CREATE TABLE aircraft_models (
    -- Сурогатний ключ на основі послідовності (AUTO_INCREMENT)
    model_id INT AUTO_INCREMENT PRIMARY KEY, 
    -- Вимога на унікальність (UNIQUE) та обов'язковість (NOT NULL)
    model_name VARCHAR(50) NOT NULL UNIQUE,       
    -- Перевірка CHECK: кількість місць має бути більше нуля
    seats_count INT NOT NULL CHECK (seats_count > 0),                     
    -- Перевірка CHECK: вантажопідйомність має бути додатною
    payload_capacity INT NOT NULL CHECK (payload_capacity > 0)                 
);

-- 2. Таблиця літаків
CREATE TABLE aircraft (
    -- Природний первинний ключ (не сурогатний)
    tail_number VARCHAR(20) PRIMARY KEY,          
    -- Зовнішній ключ (Foreign Key)
    model_id INT NOT NULL,                        
    -- Значення за замовчуванням (DEFAULT) та перевірка на невід'ємність
    hours_worked DECIMAL(10, 2) DEFAULT 0.0 CHECK (hours_worked >= 0),      
    FOREIGN KEY (model_id) REFERENCES aircraft_models(model_id) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- 3. Таблиця екіпажу
CREATE TABLE crew_members (
    member_id INT AUTO_INCREMENT PRIMARY KEY,
    last_name VARCHAR(100) NOT NULL,              
    birth_date DATE NOT NULL,                     
    -- Поле може бути порожнім (дозволено NULL за замовчуванням, якщо не вказано NOT NULL)
    address VARCHAR(255) NULL,                         
    role ENUM('Commander', 'Pilot', 'Stewardess') NOT NULL,
    -- Перевірка CHECK: приймаємо на роботу тільки повнолітніх (умовно, народжених до 2008 року)
    CHECK (birth_date < '2008-01-01')
);

-- 4. Ліцензії пілотів
CREATE TABLE pilot_allowed_models (
    pilot_id INT NOT NULL,
    model_id INT NOT NULL,
    -- Композитний первинний ключ
    PRIMARY KEY (pilot_id, model_id),
    -- Каскадне видалення (якщо видаляють пілота, його ліцензії теж зникають)
    FOREIGN KEY (pilot_id) REFERENCES crew_members(member_id) ON DELETE CASCADE,
    FOREIGN KEY (model_id) REFERENCES aircraft_models(model_id) ON DELETE CASCADE
);

-- 5. Таблиця рейсів
CREATE TABLE flights (
    flight_id INT AUTO_INCREMENT PRIMARY KEY,
    flight_number VARCHAR(15) NOT NULL UNIQUE,           
    departure_point VARCHAR(100) NOT NULL,        
    destination_point VARCHAR(100) NOT NULL,      
    departure_time DATETIME NOT NULL,             
    landing_time DATETIME NOT NULL,               
    tail_number VARCHAR(20) NOT NULL,             
    tickets_sold INT DEFAULT 0 CHECK (tickets_sold >= 0),                   
    status ENUM('Scheduled', 'Performed', 'Cancelled') DEFAULT 'Scheduled',
    -- Перевірка CHECK: час посадки має бути суворо ПІСЛЯ часу вильоту
    CHECK (landing_time > departure_time),
    FOREIGN KEY (tail_number) REFERENCES aircraft(tail_number) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- 6. Призначення на рейс
CREATE TABLE flight_crew_assignments (
    flight_id INT NOT NULL,
    member_id INT NOT NULL,
    PRIMARY KEY (flight_id, member_id),
    FOREIGN KEY (flight_id) REFERENCES flights(flight_id) ON DELETE CASCADE,
    FOREIGN KEY (member_id) REFERENCES crew_members(member_id) ON DELETE RESTRICT
);
-- Додаємо моделі
INSERT INTO aircraft_models (model_name, seats_count, payload_capacity) 
VALUES ('Boeing 737', 150, 5000), ('Ан-24', 200, 2000), ('Airbus A350', 170, 3000) ;

-- Додаємо конкретні літаки (id моделі береться з попереднього кроку: 1 і 2)
INSERT INTO aircraft (tail_number, model_id, hours_worked) 
VALUES ('UR-111', 1, 120.5), ('UR-222', 2, 0), ('UR-333', 3, 501);

-- Додаємо екіпаж (адресу вказуємо для першого, для другого залишаємо NULL)
INSERT INTO crew_members (last_name, birth_date, address, role) 
VALUES 
('Шевченко', '1985-05-15', 'Київ, Хрещатик 1', 'pilot'),
('Петренко', '1990-08-20', NULL, 'pilot'),
('Іванова', '1998-03-10', 'Львів, Франка 5', 'stewardess');

-- Видаємо ліцензії (Пілот 2 має допуск на Ан-24)
INSERT INTO pilot_allowed_models (pilot_id, model_id) 
VALUES (2, 2);
INSERT INTO pilot_allowed_models (pilot_id, model_id) 
VALUES 
(1, 1),  -- Шевченко допущений до Boeing 737 (модель 1)
(1, 2),  -- Шевченко допущений до Ан-24 (модель 2)
(2, 1),  -- Петренко допущений до Boeing 737 (модель 1)
(2, 3);  -- Петренко допущений до Airbus A350 (модель 3)

-- Створюємо рейс
INSERT INTO flights (flight_number, departure_point, destination_point, departure_time, landing_time, tail_number, tickets_sold, status) 
VALUES 
('PS-101', 'Kyiv', 'Lviv', '2026-06-01 10:00:00', '2026-06-01 11:30:00', 'UR-222', 145, 'scheduled'),
('PS-102', 'Kyiv', 'Lviv', '2026-06-02 14:00:00', '2026-06-02 15:30:00', 'UR-111', 150, 'scheduled'),
('PS-121', 'Kharkiv', 'Kyiv', '2026-10-02 15:30:00', '2026-10-02 17:00:00', 'UR-111', 139, 'scheduled');
-- Рейси що вилетіли або заплановані, з більш ніж 100 проданими квитками

INSERT INTO flight_crew_assignments (flight_id, member_id) 
VALUES 
-- Рейс PS-101 (Kyiv → Lviv)
(1, 1),  -- Шевченко (pilot)
(1, 3),  -- Іванова (stewardess)

-- Рейс PS-121 (Kharkiv → Kyiv)
(2, 2),  -- Петренко (pilot)
(2, 3);  -- Іванова (stewardess)