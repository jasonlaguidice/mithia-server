-- Blackjack Bank System
-- Creates a table to manage the blackjack NPC's gold bank

USE RTK;

SET @script = 'blackjack_bank_system.sql';

DELIMITER $$

DROP PROCEDURE IF EXISTS sp $$

CREATE PROCEDURE sp(
    IN scriptName VARCHAR(255)
)

BEGIN
    IF NOT EXISTS (SELECT * FROM MigrationHistory WHERE Script = scriptName) THEN

        -- Create blackjack_bank table to manage the NPC's gold bank
        DROP TABLE IF EXISTS `blackjack_bank`;
        CREATE TABLE `blackjack_bank` (
            `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
            `npc_identifier` varchar(50) NOT NULL DEFAULT 'blackjack_dealer',
            `bank_gold` bigint(20) NOT NULL DEFAULT '1000000',
            `minimum_bank` bigint(20) NOT NULL DEFAULT '100000',
            `max_bet` int(10) NOT NULL DEFAULT '100000',
            `min_bet` int(10) NOT NULL DEFAULT '10000',
            `is_active` tinyint(1) NOT NULL DEFAULT '1',
            `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `npc_identifier` (`npc_identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=latin1;

        -- Insert initial bank data
        INSERT INTO `blackjack_bank` (`npc_identifier`, `bank_gold`, `minimum_bank`, `max_bet`, `min_bet`, `is_active`)
        VALUES ('blackjack_dealer', 1000000, 100000, 100000, 10000, 1);

        -- Create blackjack_transactions table to log all betting transactions
        DROP TABLE IF EXISTS `blackjack_transactions`;
        CREATE TABLE `blackjack_transactions` (
            `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
            `player_name` varchar(50) NOT NULL,
            `bet_amount` int(10) NOT NULL,
            `result` enum('win','loss','push','blackjack') NOT NULL,
            `payout` int(10) NOT NULL DEFAULT '0',
            `player_hand` varchar(100) DEFAULT NULL,
            `dealer_hand` varchar(100) DEFAULT NULL,
            `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `player_name` (`player_name`),
            KEY `timestamp` (`timestamp`)
        ) ENGINE=InnoDB DEFAULT CHARSET=latin1;

        -- Create blackjack_managers table to manage who can add gold to bank
        DROP TABLE IF EXISTS `blackjack_managers`;
        CREATE TABLE `blackjack_managers` (
            `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
            `player_name` varchar(50) NOT NULL,
            `can_add_gold` tinyint(1) NOT NULL DEFAULT '1',
            `can_view_stats` tinyint(1) NOT NULL DEFAULT '1',
            `added_by` varchar(50) DEFAULT NULL,
            `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `player_name` (`player_name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=latin1;

        -- Mark this script as executed
        INSERT INTO MigrationHistory (Script, ExecutedAt) VALUES (scriptName, NOW());

    END IF;
END $$

DELIMITER ;

CALL sp(@script);
DROP PROCEDURE sp;