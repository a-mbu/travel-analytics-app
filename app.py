"""
Author: Alphonse Mbu
Project: Travel Analytics
Purpose: Analyze flight delays and wheather impact between cities
"""

import os
import sqlite3
from datetime import datetime
from threading import ExceptHookArgs

from flask import Flask, jsonify, request
from flask_sqlalchemy import SQLAlchemy, query
from sqlalchemy import text

# Initialize the Flask application
app = Flask(__name__)

# Configure SQlite database - Working Config
basedir = os.path.abspath(os.path.dirname(__file__))
# FIX: Changed URL to URI and added the missing 'S' to MODIFICATIONS
# app.config["SQLALCHEMY_DATABASE_URI"] = "sqlite:////" + os.path.join(
#    basedir, "travel.db"
# )
app.config["SQLALCHEMY_DATABASE_URI"] = "sqlite:////tmp/travel.db"
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

# Initialize SQlAlchemy
db = SQLAlchemy(app)


################################################
# DATABASE MODELS
###############################################
class Flight(db.Model):
    """Flight model- store basic information about the flight"""

    __tablename__ = "flights"
    id = db.Column(db.Integer, primary_key=True)
    flight_number = db.Column(db.String(20), nullable=False)
    airline = db.Column(db.String(50))
    origin = db.Column(db.String(3), nullable=False)
    destination = db.Column(db.String(3), nullable=False)
    departure_time = db.Column(db.DateTime)
    arrival_time = db.Column(db.DateTime)
    status = db.Column(db.String(20), default="scheduled")
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    # ADDED: This explicit init makes the Zed linter happy
    def __init__(self, **kwargs):
        super(Flight, self).__init__(**kwargs)

    def to_dict(self):
        """Convert model to dictionary for json response"""
        return {
            "id": self.id,
            "flight_number": self.flight_number,
            "airline": self.airline,
            "origin": self.origin,
            "destination": self.destination,  # Fixed typo: 'destionation'
            "departure_time": self.departure_time.isoformat()
            if self.departure_time
            else None,
            "arrival_time": self.arrival_time.isoformat()
            if self.arrival_time  # Fixed logic: was checking departure_time
            else None,
            "status": self.status,
        }


class WeatherCache(db.Model):
    """Weather cache - store recent wheather data to avoid API calls"""

    __tablename__ = "weather_cache"
    id = db.Column(db.Integer, primary_key=True)
    city = db.Column(db.String(50), nullable=False)
    temperature = db.Column(db.Float)
    conditions = db.Column(db.String(100))
    wind_speed = db.Column(db.Float)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)

    def __init__(self, **kwargs):
        super(WeatherCache, self).__init__(**kwargs)

    def to_dict(self):
        return {
            "city": self.city,
            "temperature": self.temperature,
            "conditions": self.conditions,
            "wind_speed": self.wind_speed,
            "timestamp": self.timestamp.isoformat(),
        }


##########################################
# CREATE DATABASE TABLES
#########################################

# In modern Flask, we use the app context to initialize the DB once
# rather than using @app.before_request on every single hit.
with app.app_context():
    db.create_all()

    if Flight.query.count() == 0:
        sample_flights = [
            Flight(
                flight_number="AA123",
                airline="American Airlines",
                origin="JFK",
                destination="LAX",
                departure_time=datetime(2024, 1, 15, 10, 0),
                arrival_time=datetime(2024, 1, 15, 13, 30),
                status="on_time",
            ),
            Flight(
                flight_number="UA456",
                airline="United Airlines",
                origin="SFO",
                destination="ORD",
                departure_time=datetime(2024, 1, 15, 14, 0),
                arrival_time=datetime(2024, 1, 15, 20, 15),
                status="delayed",
            ),
        ]
        db.session.bulk_save_objects(sample_flights)
        db.session.commit()  # Fixed: Added missing ()


@app.route("/")
def index():
    """Root Engpoint - Api health check"""
    return jsonify(
        {
            "service": "Travel Analytics Platorm",
            "status": "operational",
            "stage": "1",
            "database": "SQLite",
            "enpoints": [
                "/api/v1/flights",
                "/api/v1/flights/<id>",
                "/api/v1/weather/city",
                "/api/v1/health",
            ],
        }
    )


@app.route("/api/v1/health")
def health():
    """Health check endpoint for container orchestration"""
    try:
        db.session.execute(text("SELECT 1"))
        db_status = "connected"
    except Exception as e:
        db_status = f"error {str(e)}"
    return jsonify(
        {
            "status": "healthy",
            "timestamp": datetime.utcnow().isoformat(),
            "database": db_status,
            "version": "1.0.0",
        }
    )


@app.route("/api/v1/flights", methods=["GET"])
def get_flights():
    """
    GET /api/v1/flights
    Return all flights from database
    Query params: origin, destinatio, airline(filtering)
    """

    # Start with Intial/Base Query
    query = Flight.query

    # Apply Filter if provided

    origin = request.args.get("origin")
    destination = request.args.get("destination")
    airline = request.args.get("airline")
    print(airline)

    if origin:
        query = query.filter(Flight.origin == origin.upper())
    if destination:
        query = query.filter(Flight.destination == destination.upper())
    if airline:
        print(airline)
        query = query.filter(Flight.airline.ilike(f"%{airline}%"))

    # Exec query and conver to dict

    flights = query.all()
    return jsonify(
        {"count": len(flights), "flight": [flight.to_dict() for flight in flights]}
    )


@app.route("/api/v1/flights/<int:flight_id>", methods=["GET"])
def get_light(flight_id):
    """
    GET /api/v1/flight/{id}
    Return specific flight by Id
    """

    flight = Flight.query.get(flight_id)
    if flight:
        return jsonify(flight.to_dict())
    return jsonify({"error": "Flight not found"})


@app.route("/api/v1/weather/<city>")
def get_weather(city):
    """
    GET /api/v1/weather/{city}
    STAGE 1: return mock weather data (no external api)
    STAGE 3+: Integrate with OpenWeatherMap, store in warehouse
    """

    # check cache first
    cached = WeatherCache.query.filter_by(city=city.lower()).first()

    # return cached data if less than 1 hour old
    if cached and (datetime.utcnow() - cached.timestamp).seconds < 3600:
        return jsonify(cached.to_dict())
    # Mock weather data for different cities
    weather_data = {
        "new york": {"temp": 45, "conditions": "partly cloudy", "wind": 12},
        "london": {"temp": 52, "conditions": "rain", "wind": 8},
        "tokyo": {"temp": 63, "conditions": "clear", "wind": 5},
        "sydney": {"temp": 75, "conditions": "sunny", "wind": 10},
        "chicago": {"temp": 38, "conditions": "snow", "wind": 15},
        "los angeles": {"temp": 72, "conditions": "sunny", "wind": 6},
        "miami": {"temp": 80, "conditions": "humid", "wind": 8},
        "default": {"temp": 70, "conditions": "clear", "wind": 5},
    }

    # Get weather for city (case insensitive)
    city_lower = city.lower()
    data = weather_data.get(city_lower, weather_data["default"])
    # Create weather response
    weather = {
        "city": city,
        "temperature": data["temp"],
        "conditions": data["conditions"],
        "wind_speed": data["wind"],
        "timestamp": datetime.utcnow().isoformat(),
        "source": "mock_data",  # Stage 1: mock, Stage 3: external API
    }

    # Cache the result
    cache_entry = WeatherCache(
        city=city_lower,
        temperature=data["temp"],
        conditions=data["conditions"],
        wind_speed=data["wind"],
    )

    # Replace existing cache or add new
    if cached:
        cached.temperature = data["temp"]
        cached.conditions = data["conditions"]
        cached.wind_speed = data["wind"]
        cached.timestamp = datetime.utcnow()
    else:
        db.session.add(cache_entry)

    db.session.commit()

    return jsonify(weather)


@app.route("/api/v1/analytics/delays", methods=["GET"])
def get_delay_analytics():
    """
    GET /api/v1/analytics/delays
    STAGE 1: Basic analytics from SQLite
    STAGE 3: Spark aggregations on large datasets
    """

    # simple analytics - count flight by status
    total_flights = Flight.query.count()
    on_time = Flight.query.filter_by(status="on_time").count()
    delayed = Flight.query.filter_by(status="delayed").count()
    canceled = Flight.query.filter_by(status="delayed").count()

    return jsonify(
        {
            "total_flights": total_flights,
            "on_time_percentage": round(
                (on_time / total_flights) * 100 if total_flights > 0 else 0, 2
            ),
            "by_status": {"on_time": on_time, "delayed": delayed, "canceled": canceled},
            "message": "Stage 1: Basic SQLite analytics. Stage 3: Spark streaming aggregations",
        }
    )


@app.cli.command("init-db")
def init_db_command():
    """Initialize database with tables and sample data"""
    db.create_all()
    print("Initialize database")


if __name__ == "__main__":
    # Create database tables before starting
    with app.app_context():
        db.create_all()
    app.run(host="0.0.0.0", port=5000, debug=True)
