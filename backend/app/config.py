"""
Application configuration and settings management.

Loads configuration from environment variables (.env file).
Uses Pydantic BaseSettings for validation and type safety.
"""
from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    """Application configuration settings.
    
    Attributes:
        MQTT_HOST (str): MQTT broker hostname
        MQTT_PORT (int): MQTT broker port
        MQTT_USER (str): MQTT authentication username
        MQTT_PASSWORD (str): MQTT authentication password
        MQTT_TOPIC (str): MQTT subscription topic pattern
        SERVER_HOST (str): Server binding address
        SERVER_PORT (int): Server listening port
        APP_NAME (str): Application display name
        APP_VERSION (str): Application version
        DEBUG (bool): Debug mode flag
        FCM_ENABLED (bool): Firebase Cloud Messaging enabled
        FIREBASE_CREDENTIALS_PATH (str, optional): Path to Firebase credentials JSON
        FCM_DANGER_REMINDER_SEC (int): Danger alert reminder interval
        FCM_DEFAULT_USER_ID (str): Default user ID for alerts
        DB_HOST (str): Database server hostname
        DB_PORT (int): Database server port
        DB_NAME (str): Database name
        DB_USER (str): Database username
        DB_PASSWORD (str): Database password
        JWT_SECRET (str): Secret key for JWT signing
        JWT_ALGORITHM (str): JWT algorithm
        JWT_ACCESS_TOKEN_EXPIRE_MINUTES (int): Token expiry time in minutes
    """
    
    # MQTT Configuration
    MQTT_HOST: str
    MQTT_PORT: int = 8883
    MQTT_USER: str
    MQTT_PASSWORD: str
    MQTT_TOPIC: str = "iot/microclimate/+"
    
    # Server Configuration
    SERVER_HOST: str = "0.0.0.0"
    SERVER_PORT: int = 8000
    
    # Application Metadata
    APP_NAME: str = "MicroClimate AI Pro Backend"
    APP_VERSION: str = "2.1.0"
    DEBUG: bool = True

    # Firebase Cloud Messaging Configuration
    FCM_ENABLED: bool = False
    FIREBASE_CREDENTIALS_PATH: Optional[str] = None
    FCM_DANGER_REMINDER_SEC: int = 300
    FCM_DEFAULT_USER_ID: str = "user_1"

    # Database Configuration
    DB_HOST: str = "localhost"
    DB_PORT: int = 5432
    DB_NAME: str = "iot_diplom"
    DB_USER: str = "postgres"
    DB_PASSWORD: str = "1234"

    # JWT Authentication
    JWT_SECRET: str = "super_secret_change_me"
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7
    
    class Config:
        env_file = ".env"
        case_sensitive = True


# Global settings instance used throughout the application
settings = Settings()
