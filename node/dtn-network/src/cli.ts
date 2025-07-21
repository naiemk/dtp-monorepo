#!/usr/bin/env node

import { Command } from 'commander';
import yaml from 'yaml';
import fs from 'fs';
import { DtnService } from './dtnService';
import { RequestReader } from './requestReader';
import { ResponseGenerator } from './responseGenerator';
import { RequestParser } from './RequestParser';
import { configureNode } from './scripts/confiureNode';
import type { NodeConfig } from './types';
import dotenv from 'dotenv';
import { Logger, LogLevel } from './logger';

// Load environment variables from multiple possible config files
const envFiles = ['.env', '.env.production', 'localConfig/.env'];
let envLoaded = false;

for (const envFile of envFiles) {
    if (fs.existsSync(envFile)) {
        dotenv.config({ path: envFile });
        console.log(`📄 Loaded environment from: ${envFile}`);
        envLoaded = true;
        break;
    }
}

if (!envLoaded) {
    console.warn('⚠️  No environment file found. Tried:', envFiles.join(', '));
}

const program = new Command();

// CLI version and description
program
    .name('dtn-node')
    .description('DTN Network Node CLI')
    .version('1.0.0');

// Global options
program
    .option('-c, --config <path>', 'Path to configuration file', './nodeConfig.yaml')
    .option('-v, --verbose', 'Enable verbose logging')
    .option('--log-level <level>', 'Set log level (error, warn, info, debug, trace)', 'info');

/**
 * Utility to parse log level string to LogLevel enum
 */
function parseLogLevel(level: string): LogLevel {
    switch (level.toLowerCase()) {
        case 'error': return LogLevel.ERROR;
        case 'warn': return LogLevel.WARN;
        case 'info': return LogLevel.INFO;
        case 'debug': return LogLevel.DEBUG;
        case 'trace': return LogLevel.TRACE;
        default:
            console.warn(`Unknown log level: ${level}, defaulting to INFO`);
            return LogLevel.INFO;
    }
}

/**
 * Initialize logging configuration
 */
function initializeLogging(verbose: boolean, logLevelStr: string): LogLevel {
    let logLevel: LogLevel;
    if (verbose) {
        console.log('🔧 Initializing logging with verbose mode...');
        logLevel = LogLevel.DEBUG;
    } else {
        logLevel = parseLogLevel(logLevelStr);
        console.log(`🔧 Initializing logging with log level: ${LogLevel[logLevel]}`);
    }
    process.env.LOG_LEVEL = LogLevel[logLevel].toLowerCase();
    return logLevel;
}

/**
 * Load and validate configuration
 */
function loadConfiguration(configPath: string): NodeConfig {
    console.log(`📋 Loading configuration from: ${configPath}`);
    
    if (!fs.existsSync(configPath)) {
        throw new Error(`Configuration file not found: ${configPath}`);
    }

    try {
        const configContent = fs.readFileSync(configPath, 'utf8');
        const config = yaml.parse(configContent) as NodeConfig;
        
        // Validate required environment variables
        validateEnvironmentVariables(config);
        
        console.log('✅ Configuration loaded successfully');
        return config;
    } catch (error) {
        throw new Error(`Failed to load configuration: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
}

/**
 * Validate required environment variables
 */
function validateEnvironmentVariables(config: NodeConfig): void {
    console.log('🔍 Validating environment variables...');
    
    const requiredVars = [
        config.keys.ownerPrivateKey,
        config.keys.workerPrivateKey
    ];

    const missingVars = requiredVars.filter(varName => !process.env[varName]);
    
    if (missingVars.length > 0) {
        throw new Error(`Missing required environment variables: ${missingVars.join(', ')}`);
    }
    
    console.log('✅ Environment variables validated');
}

/**
 * Initialize DTN service dependencies
 */
function initializeDtnService(config: NodeConfig, logLevel: LogLevel): DtnService {
    console.log('🔧 Initializing DTN service dependencies...');
    
    try {
        const requestReader = new RequestReader(config, logLevel);
        const requestParser = new RequestParser(config, logLevel);
        const responseGenerator = new ResponseGenerator(config, requestParser, logLevel);
        const dtnService = new DtnService(config, requestReader, responseGenerator, logLevel);
        
        console.log('✅ DTN service dependencies initialized');
        return dtnService;
    } catch (error) {
        throw new Error(`Failed to initialize DTN service: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
}

/**
 * Run DTN service once
 */
async function runOnce(config: NodeConfig, logLevel: LogLevel): Promise<void> {
    console.log('🚀 Running DTN service once...');
    
    try {
        const dtnService = initializeDtnService(config, logLevel);
        await dtnService.processRequests();
        console.log('✅ DTN service completed successfully');
    } catch (error) {
        console.error(error);
        console.error('❌ DTN service failed:', error instanceof Error ? error.message : 'Unknown error');
        process.exit(1);
    }
}

/**
 * Run DTN service in a loop
 */
async function runLoop(config: NodeConfig, intervalSeconds: number = 5, logLevel: LogLevel): Promise<void> {
    console.log(`🔄 Running DTN service in loop (interval: ${intervalSeconds}s)...`);
    
    const dtnService = initializeDtnService(config, logLevel);
    
    // Handle graceful shutdown
    process.on('SIGINT', () => {
        console.log('\n🛑 Received SIGINT, shutting down gracefully...');
        process.exit(0);
    });
    
    process.on('SIGTERM', () => {
        console.log('\n🛑 Received SIGTERM, shutting down gracefully...');
        process.exit(0);
    });
    
    while (true) {
        try {
            await dtnService.processRequests();
            console.log(`⏳ Waiting ${intervalSeconds} seconds before next iteration...`);
            await new Promise(resolve => setTimeout(resolve, intervalSeconds * 1000));
        } catch (error) {
            console.error('❌ Error in DTN service loop:', error instanceof Error ? error.message : 'Unknown error');
            console.log(`⏳ Waiting ${intervalSeconds} seconds before retry...`);
            await new Promise(resolve => setTimeout(resolve, intervalSeconds * 1000));
        }
    }
}

/**
 * Configure node
 */
async function configureNodeCommand(configPath: string): Promise<void> {
    console.log('⚙️  Configuring node...');
    
    try {
        await configureNode(configPath);
        console.log('✅ Node configuration completed successfully');
    } catch (error) {
        console.error('❌ Node configuration failed:', error instanceof Error ? error.message : 'Unknown error');
        process.exit(1);
    }
}

// CLI Commands

program
    .command('run-once')
    .description('Run the DTN service once')
    .action(async (options) => {
        const { config: configPath, verbose, logLevel } = program.opts();
        
        try {
            const selectedLogLevel = initializeLogging(verbose, logLevel);
            const config = loadConfiguration(configPath);
            await runOnce(config, selectedLogLevel);
        } catch (error) {
            console.error('❌ Command failed:', error instanceof Error ? error.message : 'Unknown error');
            process.exit(1);
        }
    });

program
    .command('loop')
    .description('Run the DTN service in a continuous loop')
    .option('-i, --interval <seconds>', 'Interval between iterations in seconds', '5')
    .action(async (options) => {
        const { config: configPath, verbose, logLevel } = program.opts();
        const interval = parseInt(options.interval);
        
        if (isNaN(interval) || interval < 1) {
            console.error('❌ Invalid interval. Must be a positive number.');
            process.exit(1);
        }
        
        try {
            const selectedLogLevel = initializeLogging(verbose, logLevel);
            const config = loadConfiguration(configPath);
            await runLoop(config, interval, selectedLogLevel);
        } catch (error) {
            console.error('❌ Command failed:', error instanceof Error ? error.message : 'Unknown error');
            process.exit(1);
        }
    });

program
    .command('configure-node')
    .description('Configure the node on the blockchain')
    .action(async (options) => {
        const { config: configPath, verbose } = program.opts();
        
        try {
            initializeLogging(verbose, 'info'); // ConfigureNodeCommand doesn't have --log-level
            await configureNodeCommand(configPath);
        } catch (error) {
            console.error('❌ Command failed:', error instanceof Error ? error.message : 'Unknown error');
            process.exit(1);
        }
    });

// Error handling for unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
    console.error('❌ Unhandled Rejection at:', promise, 'reason:', reason);
    process.exit(1);
});

// Parse command line arguments
program.parse(process.argv); 