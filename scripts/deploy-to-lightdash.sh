#!/bin/bash
set -e

# Poverty Stoplight - Lightdash Deployment Script
# This script automates the deployment of dbt models to Lightdash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [[ ! -f "dbt/dbt_project.yml" ]]; then
    print_error "Please run this script from the project root directory"
    print_error "Usage: ./scripts/deploy-to-lightdash.sh"
    exit 1
fi

print_status "Starting Lightdash deployment for Poverty Stoplight Data Build"

# Check prerequisites
print_status "Checking prerequisites..."

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    print_error "Node.js is not installed. Please install Node.js first."
    exit 1
fi

# Check if uv is installed
if ! command -v uv &> /dev/null; then
    print_error "uv is not installed. Please install uv first."
    exit 1
fi

# Check if dbt is installed
if ! command -v dbt &> /dev/null; then
    print_warning "dbt is not installed. Installing dbt-core with PostgreSQL adapter..."
    uv tool install dbt-core --with dbt-postgres
    print_success "dbt installed successfully"
fi

# Check if Lightdash CLI is installed
if ! command -v lightdash &> /dev/null; then
    print_warning "Lightdash CLI is not installed. Installing..."
    npm install -g @lightdash/cli@0.2001.1
    print_success "Lightdash CLI installed successfully"
fi

# Check if .env file exists
if [[ ! -f ".env" ]]; then
    print_error ".env file not found in project root"
    print_error "Please create a .env file with your database connection details:"
    echo ""
    echo "export DBT_HOST=\"your-postgres-host\""
    echo "export DBT_USER=\"your-username\""
    echo "export DBT_PASSWORD=\"your-password\""
    echo "export DBT_PORT=\"5432\""
    echo "export DBT_DBNAME=\"your-database-name\""
    echo "export DBT_SCHEMA=\"dbt_dev\""
    exit 1
fi

# Source environment variables
print_status "Loading environment variables..."
source .env

# Verify required environment variables
required_vars=("DBT_HOST" "DBT_USER" "DBT_PASSWORD" "DBT_DBNAME")
for var in "${required_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
        print_error "Required environment variable $var is not set in .env file"
        exit 1
    fi
done

print_success "Environment variables loaded successfully"

# Check Lightdash login status
print_status "Checking Lightdash authentication..."
if ! lightdash whoami &> /dev/null; then
    print_warning "Not logged in to Lightdash. Please login first:"
    print_warning "Run: lightdash login http://localhost:8080 --token YOUR_TOKEN"
    exit 1
fi

print_success "Authenticated with Lightdash"

# Navigate to dbt directory
cd dbt

# Test dbt connection
print_status "Testing dbt connection..."
if ! dbt debug --quiet; then
    print_error "dbt connection test failed. Please check your database credentials."
    exit 1
fi

print_success "dbt connection test passed"

# Deploy to Lightdash
print_status "Deploying to Lightdash..."
print_status "This will compile your dbt models and create/update the Lightdash project"

# Run the deployment
lightdash deploy --create --project-name "PSP Data Build - Prod"

print_success "Lightdash deployment completed!"
print_status "Your models are now available at: http://localhost:8080"
print_status ""
print_status "Available models in Lightdash:"
print_status "- mart_global_survey_coverage (Survey deployment and family engagement metrics)"
print_status "- mart_global_indicator_catalog (Master inventory of poverty indicators)"
print_status "- mart_py_family_current_state (Paraguay family poverty status and progression)"