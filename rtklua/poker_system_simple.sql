-- Poker System Database Schema (Simplified - No Migration Tracking)
USE RTK;

-- Create poker_accounts table for player chip accounts
CREATE TABLE IF NOT EXISTS `poker_accounts` (
    `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `player_name` varchar(50) NOT NULL,
    `chip_balance` bigint(20) NOT NULL DEFAULT '0',
    `total_deposited` bigint(20) NOT NULL DEFAULT '0',
    `total_withdrawn` bigint(20) NOT NULL DEFAULT '0',
    `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `player_name` (`player_name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- Create poker_tables table for managing active poker tables
CREATE TABLE IF NOT EXISTS `poker_tables` (
    `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `table_name` varchar(50) NOT NULL,
    `max_players` int(2) NOT NULL DEFAULT '6',
    `small_blind` int(10) NOT NULL DEFAULT '1000',
    `big_blind` int(10) NOT NULL DEFAULT '2000',
    `min_buyin` int(10) NOT NULL DEFAULT '20000',
    `max_buyin` int(10) NOT NULL DEFAULT '200000',
    `is_active` tinyint(1) NOT NULL DEFAULT '1',
    `current_game_id` int(10) unsigned DEFAULT NULL,
    `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `table_name` (`table_name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- Insert default poker table
INSERT INTO `poker_tables` (`table_name`, `max_players`, `small_blind`, `big_blind`, `min_buyin`, `max_buyin`)
VALUES ('Main Table', 6, 1000, 2000, 20000, 200000)
ON DUPLICATE KEY UPDATE `table_name`='Main Table';

-- Create poker_games table for tracking active games
CREATE TABLE IF NOT EXISTS `poker_games` (
    `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `table_id` int(10) unsigned NOT NULL,
    `game_state` enum('waiting','preflop','flop','turn','river','showdown','finished') NOT NULL DEFAULT 'waiting',
    `current_player_turn` varchar(50) DEFAULT NULL,
    `dealer_position` int(2) NOT NULL DEFAULT '0',
    `small_blind_position` int(2) NOT NULL DEFAULT '0',
    `big_blind_position` int(2) NOT NULL DEFAULT '0',
    `current_bet` int(10) NOT NULL DEFAULT '0',
    `pot_amount` int(10) NOT NULL DEFAULT '0',
    `community_cards` text DEFAULT NULL,
    `deck_state` text DEFAULT NULL,
    `turn_start_time` timestamp NULL DEFAULT NULL,
    `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `table_id` (`table_id`),
    FOREIGN KEY (`table_id`) REFERENCES `poker_tables` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- Create poker_players table for tracking players in games
CREATE TABLE IF NOT EXISTS `poker_players` (
    `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `game_id` int(10) unsigned NOT NULL,
    `player_name` varchar(50) NOT NULL,
    `seat_position` int(2) NOT NULL,
    `chip_count` int(10) NOT NULL,
    `hole_cards` varchar(20) DEFAULT NULL,
    `current_bet` int(10) NOT NULL DEFAULT '0',
    `total_bet_this_round` int(10) NOT NULL DEFAULT '0',
    `is_folded` tinyint(1) NOT NULL DEFAULT '0',
    `is_all_in` tinyint(1) NOT NULL DEFAULT '0',
    `is_sitting_out` tinyint(1) NOT NULL DEFAULT '0',
    `joined_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `game_id` (`game_id`),
    KEY `player_name` (`player_name`),
    UNIQUE KEY `game_seat` (`game_id`, `seat_position`),
    FOREIGN KEY (`game_id`) REFERENCES `poker_games` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- Create poker_hand_history table for completed hands
CREATE TABLE IF NOT EXISTS `poker_hand_history` (
    `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `game_id` int(10) unsigned NOT NULL,
    `hand_number` int(10) NOT NULL,
    `winner_name` varchar(50) DEFAULT NULL,
    `winning_hand` varchar(100) DEFAULT NULL,
    `pot_amount` int(10) NOT NULL,
    `community_cards` varchar(50) DEFAULT NULL,
    `players_data` text DEFAULT NULL,
    `completed_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `game_id` (`game_id`),
    KEY `winner_name` (`winner_name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- Create poker_transactions table for chip movements
CREATE TABLE IF NOT EXISTS `poker_transactions` (
    `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `player_name` varchar(50) NOT NULL,
    `transaction_type` enum('deposit','withdraw','win','loss','buyin','cashout') NOT NULL,
    `amount` int(10) NOT NULL,
    `balance_before` bigint(20) NOT NULL,
    `balance_after` bigint(20) NOT NULL,
    `description` varchar(255) DEFAULT NULL,
    `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `player_name` (`player_name`),
    KEY `transaction_type` (`transaction_type`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- Create poker_managers table to manage who can control poker settings
CREATE TABLE IF NOT EXISTS `poker_managers` (
    `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `player_name` varchar(50) NOT NULL,
    `can_toggle_npc` tinyint(1) NOT NULL DEFAULT '1',
    `can_manage_tables` tinyint(1) NOT NULL DEFAULT '1',
    `can_view_stats` tinyint(1) NOT NULL DEFAULT '1',
    `can_force_end_games` tinyint(1) NOT NULL DEFAULT '1',
    `added_by` varchar(50) DEFAULT NULL,
    `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `player_name` (`player_name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- Create poker_settings table for NPC configuration
CREATE TABLE IF NOT EXISTS `poker_settings` (
    `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `setting_name` varchar(50) NOT NULL,
    `setting_value` varchar(255) NOT NULL,
    `description` varchar(255) DEFAULT NULL,
    `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `setting_name` (`setting_name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- Insert default settings
INSERT INTO `poker_settings` (`setting_name`, `setting_value`, `description`) VALUES
('npc_active', '1', 'Whether poker NPC is active (1) or closed (0)'),
('turn_timeout_seconds', '30', 'Seconds before turn times out'),
('popup_retry_seconds', '5', 'Seconds before re-showing popup if closed'),
('min_players_to_start', '2', 'Minimum players needed to start a game'),
('max_tables', '5', 'Maximum number of concurrent tables')
ON DUPLICATE KEY UPDATE `setting_name`=VALUES(`setting_name`);
