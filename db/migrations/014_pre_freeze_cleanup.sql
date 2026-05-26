-- Pre-freeze: audit user_id для pattern_*; удалить NOP-триггер streak.
DROP TRIGGER IF EXISTS trg_pattern_streak_recalc ON pattern_logs;
DROP FUNCTION IF EXISTS fn_pattern_streak_touch();

CREATE OR REPLACE FUNCTION fn_audit_log()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_action audit_action_enum;
    v_user   BIGINT;
    v_row_id BIGINT;
    v_diff   JSONB;
    v_row    JSONB;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_action := 'insert';
        v_row := to_jsonb(NEW);
        v_row_id := (v_row ->> 'id')::BIGINT;
        v_user   := (v_row ->> 'user_id')::BIGINT;
        v_diff   := jsonb_build_object('new', v_row);
    ELSIF TG_OP = 'UPDATE' THEN
        v_action := 'update';
        v_row := to_jsonb(NEW);
        v_row_id := (v_row ->> 'id')::BIGINT;
        v_user   := (v_row ->> 'user_id')::BIGINT;
        v_diff   := jsonb_build_object('old', to_jsonb(OLD), 'new', v_row);
    ELSE
        v_action := 'delete';
        v_row := to_jsonb(OLD);
        v_row_id := (v_row ->> 'id')::BIGINT;
        v_user   := (v_row ->> 'user_id')::BIGINT;
        v_diff   := jsonb_build_object('old', v_row);
    END IF;

    IF v_user IS NULL
       AND TG_TABLE_NAME IN ('pattern_logs', 'pattern_markers', 'pattern_marker_day_closures') THEN
        SELECT bp.user_id INTO v_user
          FROM behavior_patterns bp
         WHERE bp.id = (v_row ->> 'pattern_id')::BIGINT;
    END IF;

    INSERT INTO audit_log (user_id, table_name, row_id, action, diff)
    VALUES (v_user, TG_TABLE_NAME, v_row_id, v_action, v_diff);

    RETURN COALESCE(NEW, OLD);
END;
$$;
