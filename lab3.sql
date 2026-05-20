
-- рейтинг одного пілота

DROP PROCEDURE IF EXISTS calculate_pilot_rating;

DELIMITER $$

CREATE PROCEDURE calculate_pilot_rating(
    IN  p_pilot_id   INT,
    OUT p_rating     DECIMAL(10,2),
    OUT p_breakdown  VARCHAR(500)
)
BEGIN
    -- Змінні для компонентів рейтингу
    DECLARE v_flight_count     INT     DEFAULT 0;
    DECLARE v_flight_hours     DECIMAL(10,2) DEFAULT 0;
    DECLARE v_model_count      INT     DEFAULT 0;
    DECLARE v_role_bonus       INT     DEFAULT 0;
    DECLARE v_role             VARCHAR(50);

    -- Кількість рейсів пілота
    SELECT COUNT(*)
    INTO   v_flight_count
    FROM   flight_crew_assignments fca
    JOIN   flights f ON fca.flight_id = f.flight_id
    WHERE  fca.member_id = p_pilot_id;

    -- Загальний наліт (у годинах) з рейсів
    SELECT COALESCE(
               SUM(TIMESTAMPDIFF(MINUTE, f.departure_time, f.landing_time) / 60.0),
               0
           )
    INTO   v_flight_hours
    FROM   flight_crew_assignments fca
    JOIN   flights f ON fca.flight_id = f.flight_id
    WHERE  fca.member_id = p_pilot_id;

    -- Кількість допущених моделей літаків
    SELECT COUNT(*)
    INTO   v_model_count
    FROM   pilot_allowed_models
    WHERE  pilot_id = p_pilot_id;

    -- Бонус за звання
    SELECT role INTO v_role
    FROM   crew_members
    WHERE  member_id = p_pilot_id;

    SET v_role_bonus = CASE v_role
        WHEN 'Commander'  THEN 30
        WHEN 'Pilot'      THEN 15
        WHEN 'Stewardess' THEN  5
        ELSE                    0
    END;

    -- Формула рейтингу:
    --   кількість рейсів   × 10 балів
    --   години нальоту     ×  2 бали
    --   кількість моделей  × 15 балів
    --   бонус за звання    (фіксований)
    SET p_rating = (v_flight_count * 10)
                 + (v_flight_hours *  2)
                 + (v_model_count  * 15)
                 +  v_role_bonus;

    SET p_breakdown = CONCAT(
        'Рейсів: ',      v_flight_count, ' (+', v_flight_count * 10,  'б) | ',
        'Годин: ',       ROUND(v_flight_hours, 1), ' (+', ROUND(v_flight_hours * 2, 1), 'б) | ',
        'Моделей: ',     v_model_count,  ' (+', v_model_count  * 15, 'б) | ',
        'Звання (',      v_role, '): +', v_role_bonus, 'б'
    );
END$$

DELIMITER ;


-- рейтинг усіх пілотів
DROP PROCEDURE IF EXISTS calculate_all_pilots_rating;

DELIMITER $$

CREATE PROCEDURE calculate_all_pilots_rating()
BEGIN
    DECLARE v_done      INT DEFAULT 0;
    DECLARE v_id        INT;
    DECLARE v_name      VARCHAR(100);
    DECLARE v_rating    DECIMAL(10,2);
    DECLARE v_breakdown VARCHAR(500);

    -- Курсор по всіх пілотах та командирах
    DECLARE cur CURSOR FOR
        SELECT member_id, last_name
        FROM   crew_members
        WHERE  role IN ('Commander', 'Pilot');

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

    -- Тимчасова таблиця для результатів
    DROP TEMPORARY TABLE IF EXISTS pilot_ratings;
    CREATE TEMPORARY TABLE pilot_ratings (
        pilot_id   INT,
        last_name  VARCHAR(100),
        rating     DECIMAL(10,2),
        rank_place INT,
        breakdown  VARCHAR(500)
    );

    OPEN cur;
    rating_loop: LOOP
        FETCH cur INTO v_id, v_name;
        IF v_done = 1 THEN LEAVE rating_loop; END IF;

        -- Викликаємо першу процедуру для кожного пілота
        CALL calculate_pilot_rating(v_id, v_rating, v_breakdown);

        INSERT INTO pilot_ratings (pilot_id, last_name, rating, breakdown)
        VALUES (v_id, v_name, v_rating, v_breakdown);
    END LOOP;
    CLOSE cur;

    -- Додаємо місце у рейтингу
    SET @rnk = 0;
    UPDATE pilot_ratings
    SET    rank_place = (@rnk := @rnk + 1)
    ORDER  BY rating DESC;

    -- Повертаємо результат
    SELECT
        rank_place      AS `Місце`,
        last_name       AS `Прізвище`,
        rating          AS `Рейтинг`,
        breakdown       AS `Розбивка балів`
    FROM pilot_ratings
    ORDER BY rank_place;
END$$

DELIMITER ;


-- Рейтинг конкретного пілота (id=1, Шевченко)
SET @r = 0; SET @b = '';
CALL calculate_pilot_rating(1, @r, @b);
SELECT @r AS rating, @b AS breakdown;

-- Рейтинг усіх пілотів
CALL calculate_all_pilots_rating();
