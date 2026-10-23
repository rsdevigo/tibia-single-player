-- Tabelas que o fork canary-bots-with-cast (v2026.09.01) usa mas não cria em lugar nenhum
-- (nem schema.sql, nem database/bots/, nem a migração 62). Colunas tiradas das queries do código:
--   bot_state_persistence -> src/creatures/players/bot/bot_engine.cpp (saveAllStates/restoreAllStates)
--   bot_startup_config    -> data/scripts/globalevents/bot_manager.lua, data/scripts/lib/bot_system.lua
--   bot_test_commands     -> data/scripts/globalevents/bot_test_commands.lua (consultada a cada segundo)
--   bot_nav_events        -> src/creatures/players/bot/bot_engine_impl.hpp (upsert a cada 30 s)
-- Aplicado pelo entrypoint a cada subida; IF NOT EXISTS torna seguro repetir.

CREATE TABLE IF NOT EXISTS `bot_state_persistence` (
	`guid` INT UNSIGNED NOT NULL,
	`name` VARCHAR(255) NOT NULL,
	`ai_state` TINYINT UNSIGNED NOT NULL DEFAULT 0,
	`hunt_script_id` INT UNSIGNED NULL,
	`hunt_phase` TINYINT UNSIGNED NULL,
	`waypoint_idx` INT UNSIGNED NULL,
	`kill_count` INT UNSIGNED NULL,
	`travel_dest_town_id` INT UNSIGNED NULL,
	PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `bot_startup_config` (
	`config_key` VARCHAR(64) NOT NULL,
	`config_value` VARCHAR(255) NOT NULL DEFAULT '',
	PRIMARY KEY (`config_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `bot_test_commands` (
	`id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
	`command` VARCHAR(255) NOT NULL,
	`executed` TINYINT(1) NOT NULL DEFAULT 0,
	`executed_at` BIGINT NULL,
	`created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	PRIMARY KEY (`id`),
	KEY `executed` (`executed`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `bot_nav_events` (
	`id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
	`event_type` VARCHAR(64) NOT NULL,
	`hunt_script_id` INT NOT NULL DEFAULT 0,
	`hunt_script_name` VARCHAR(255) NOT NULL DEFAULT '',
	`route_town_id` INT NOT NULL DEFAULT 0,
	`route_type` VARCHAR(32) NOT NULL DEFAULT '',
	`town_name` VARCHAR(64) NULL,
	`bot_name` VARCHAR(255) NOT NULL DEFAULT '',
	`context` TEXT NULL,
	`event_count` INT UNSIGNED NOT NULL DEFAULT 0,
	`first_seen` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	`last_seen` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	PRIMARY KEY (`id`),
	UNIQUE KEY `event_key` (`event_type`, `hunt_script_id`, `route_town_id`, `route_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
