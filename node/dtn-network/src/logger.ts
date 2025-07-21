export enum LogLevel {
    ERROR = 0,
    WARN = 1,
    INFO = 2,
    DEBUG = 3,
    TRACE = 4
}

export class Logger {
    private logLevel: LogLevel;

    constructor(logLevel: LogLevel = LogLevel.INFO) {
        this.logLevel = logLevel;
    }

    setLogLevel(level: LogLevel) {
        this.logLevel = level;
    }

    error(message: string, ...args: any[]) {
        if (this.logLevel >= LogLevel.ERROR) {
            console.error(`[ERROR] ${message}`, ...args);
        }
    }

    warn(message: string, ...args: any[]) {
        if (this.logLevel >= LogLevel.WARN) {
            console.warn(`[WARN] ${message}`, ...args);
        }
    }

    info(message: string, ...args: any[]) {
        if (this.logLevel >= LogLevel.INFO) {
            console.log(`[INFO] ${message}`, ...args);
        }
    }

    debug(message: string, ...args: any[]) {
        if (this.logLevel >= LogLevel.DEBUG) {
            console.log(`[DEBUG] ${message}`, ...args);
        }
    }

    trace(message: string, ...args: any[]) {
        if (this.logLevel >= LogLevel.TRACE) {
            console.log(`[TRACE] ${message}`, ...args);
        }
    }
} 