USE airport_db;
SELECT flight_number, departure_point, destination_point, tickets_sold, status
FROM flights
WHERE (status = 'departed' OR status = 'scheduled')
AND tickets_sold > 100
ORDER BY departure_time DESC;

-- Завантаженість рейсу у відсотках
SELECT 
    f.flight_number,
    f.tickets_sold,
    am.seats_count,
    ROUND(f.tickets_sold * 100.0 / am.seats_count, 1) AS load_percent,
    am.seats_count - f.tickets_sold AS free_seats
FROM flights f
JOIN aircraft a ON f.tail_number = a.tail_number
JOIN aircraft_models am ON a.model_id = am.model_id;

-- Члени екіпажу призначені на рейс, що є пілотами або старшими бортпровідниками
SELECT 
    cm.last_name, cm.role, f.flight_number, f.departure_point, f.destination_point
FROM flight_crew_assignments fca
JOIN crew_members cm ON fca.member_id = cm.member_id
JOIN flights f ON fca.flight_id = f.flight_id
WHERE (cm.role = 'pilot' OR cm.role = 'stewardess')
AND f.status = 'scheduled'
ORDER BY f.departure_time, cm.role;

-- Всі борти, навіть ті що не мають жодного запланованого рейсу
SELECT 
    a.tail_number,
    am.model_name,
    f.flight_number,
    f.departure_time
FROM aircraft a
LEFT JOIN aircraft_models am ON a.model_id = am.model_id
LEFT JOIN flights f ON a.tail_number = f.tail_number AND f.status = 'scheduled';

-- LIKE: пошук рейсів з Києва
SELECT * FROM flights WHERE departure_point LIKE '%Kyiv%';

-- BETWEEN: рейси у певному діапазоні дат
SELECT * FROM flights 
WHERE departure_time BETWEEN '2026-10-01' AND '2026-10-30';

-- IN: конкретні статуси
SELECT * FROM flights WHERE status IN ('scheduled', 'delayed');

-- EXISTS: пілоти що мають хоч один допуск
SELECT last_name FROM crew_members cm
WHERE role = 'pilot'
AND EXISTS (
    SELECT 1 FROM pilot_allowed_models 
    WHERE pilot_id = cm.member_id
);

-- ALL: борти з нальотом більшим за всі інші борти певної моделі
SELECT tail_number FROM aircraft
WHERE hours_worked > ALL (
    SELECT hours_worked FROM aircraft WHERE model_id = 2
);

-- ANY: пілоти допущені до будь-якої з цих моделей
SELECT last_name FROM crew_members cm
WHERE member_id = ANY (
    SELECT pilot_id FROM pilot_allowed_models WHERE model_id IN (1,3)
);

-- Кількість рейсів і середнє заповнення по кожному маршруту
SELECT 
    departure_point,
    destination_point,
    COUNT(*) AS total_flights,
    SUM(tickets_sold) AS total_passengers,
    AVG(tickets_sold) AS avg_passengers,
    MAX(tickets_sold) AS max_sold
FROM flights
GROUP BY departure_point, destination_point
HAVING COUNT(*) > 1
ORDER BY total_flights DESC;

-- Члени екіпажу призначені на рейси з завантаженістю > 90%
SELECT last_name, role FROM crew_members
WHERE member_id IN (
    SELECT fca.member_id 
    FROM flight_crew_assignments fca
    JOIN flights f ON fca.flight_id = f.flight_id
    JOIN aircraft a ON f.tail_number = a.tail_number
    JOIN aircraft_models am ON a.model_id = am.model_id
    WHERE f.tickets_sold * 1.0 / am.seats_count > 0.9
);

-- Середній наліт по моделях, відфільтрувати тільки "багато літаючі"
SELECT model_name, avg_hours
FROM (
    SELECT am.model_name, AVG(a.hours_worked) AS avg_hours
    FROM aircraft a
    JOIN aircraft_models am ON a.model_id = am.model_id
    GROUP BY am.model_id, am.model_name
) AS model_stats
WHERE avg_hours > 500;

-- Ієрархія: модель → борт → рейс
SELECT 
    am.model_name AS рівень_1_модель,
    a.tail_number AS рівень_2_борт,
    f.flight_number AS рівень_3_рейс,
    f.departure_time
FROM aircraft_models am
JOIN aircraft a ON am.model_id = a.model_id
JOIN flights f ON a.tail_number = f.tail_number
ORDER BY am.model_name, a.tail_number, f.departure_time;

-- Кількість рейсів по статусах для кожного маршруту
SELECT 
    departure_point,
    SUM(CASE WHEN status = 'scheduled' THEN 1 ELSE 0 END) AS scheduled,
    SUM(CASE WHEN status = 'departed'  THEN 1 ELSE 0 END) AS departed,
    SUM(CASE WHEN status = 'landed'    THEN 1 ELSE 0 END) AS landed,
    SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled
FROM flights
GROUP BY departure_point;

-- Скасувати всі рейси старіші за сьогодні зі статусом scheduled
SET SQL_SAFE_UPDATES = 0;

UPDATE flights
SET status = 'cancelled'
WHERE status = 'scheduled' AND departure_time < NOW();

SET SQL_SAFE_UPDATES = 1;

-- Оновити кількість проданих квитків до максимуму місць (овербукінг → обмежити)
SET SQL_SAFE_UPDATES = 0;

UPDATE flights f
JOIN aircraft a ON f.tail_number = a.tail_number
JOIN aircraft_models am ON a.model_id = am.model_id
SET f.tickets_sold = am.seats_count
WHERE f.tickets_sold > am.seats_count;

SET SQL_SAFE_UPDATES = 1;

INSERT INTO crew_members (last_name, birth_date, address, role)
VALUES ('Шевченко', '1985-03-15', 'Київ, вул. Хрещатик 1', 'pilot');

-- Архівна таблиця виконаних рейсів (припустимо вона є)


SET SQL_SAFE_UPDATES = 0;

DELETE FROM flight_crew_assignments;

SET SQL_SAFE_UPDATES = 1;

-- Видалити призначення екіпажу на скасовані рейси
SET SQL_SAFE_UPDATES = 0;

DELETE fca FROM flight_crew_assignments fca
JOIN flights f ON fca.flight_id = f.flight_id
WHERE f.status = 'cancelled';

-- Складний 1: пілоти з допуском до борту рейсу + завантаженість > 80%
-- Поєднує: JOIN кількох таблиць, підзапит у WHERE, обчислюване поле, ORDER BY
SELECT 
    cm.last_name,
    am.model_name,
    fl.flight_number,
    ROUND(fl.tickets_sold * 100.0 / am.seats_count, 1) AS load_pct
FROM crew_members cm
JOIN pilot_allowed_models pam ON cm.member_id = pam.pilot_id
JOIN aircraft_models am ON pam.model_id = am.model_id
JOIN aircraft a ON am.model_id = a.model_id
JOIN flights fl ON a.tail_number = fl.tail_number
WHERE cm.role = 'pilot'
AND fl.tickets_sold * 1.0 / am.seats_count > 0.8
ORDER BY load_pct DESC;
-- Складний 2: CrossTab + підзапит у FROM — завантаженість борту по місяцях
SELECT 
    tail_number,
    SUM(CASE WHEN month = 1 THEN tickets ELSE 0 END) AS січень,
    SUM(CASE WHEN month = 2 THEN tickets ELSE 0 END) AS жовтень,
    SUM(CASE WHEN month = 3 THEN tickets ELSE 0 END) AS червень
FROM (
    SELECT 
        tail_number,
        MONTH(departure_time) AS month,
        SUM(tickets_sold) AS tickets
    FROM flights
    WHERE YEAR(departure_time) = 2026
    GROUP BY tail_number, MONTH(departure_time)
) AS monthly
GROUP BY tail_number;
