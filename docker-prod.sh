#!/bin/bash

# KarHubTy Production Docker Management Script
# Usage: ./docker-prod.sh [start|stop|restart|logs|clean|build]

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env.prod"
COMPOSE_FILES="-f docker-compose.yml -f karhubty-backend/docker-compose.prod.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

check_env_file() {
    if [ ! -f "$ENV_FILE" ]; then
        log_error "Production .env file not found: $ENV_FILE"
        log_info "Please create $ENV_FILE with your production settings"
        exit 1
    fi
}

start_production() {
    check_env_file
    log_info "Starting KarHubTy in PRODUCTION mode..."
    
    log_info "Building Docker images..."
    docker-compose $COMPOSE_FILES build --no-cache
    
    log_info "Starting services..."
    docker-compose $COMPOSE_FILES up -d
    
    log_success "Production services started!"
    log_info "Backend: http://localhost:8080"
    log_info "Database: localhost:5432"
    
    log_info "Waiting for services to be healthy..."
    sleep 10
    
    # Show status
    docker-compose $COMPOSE_FILES ps
}

stop_production() {
    log_info "Stopping KarHubTy production services..."
    docker-compose $COMPOSE_FILES down
    log_success "Services stopped!"
}

restart_production() {
    log_info "Restarting KarHubTy production services..."
    stop_production
    start_production
}

view_logs() {
    check_env_file
    local service=$1
    
    if [ -z "$service" ]; then
        log_info "Showing logs for all services..."
        docker-compose $COMPOSE_FILES logs -f
    else
        log_info "Showing logs for $service..."
        docker-compose $COMPOSE_FILES logs -f "$service"
    fi
}

clean_volumes() {
    log_warning "This will DELETE all production data!"
    read -p "Are you sure? Type 'yes' to confirm: " confirm
    
    if [ "$confirm" = "yes" ]; then
        log_info "Removing containers, volumes, and networks..."
        docker-compose $COMPOSE_FILES down -v
        log_success "Cleanup complete!"
    else
        log_info "Cleanup cancelled"
    fi
}

build_only() {
    check_env_file
    log_info "Building Docker images without starting..."
    docker-compose $COMPOSE_FILES build --no-cache
    log_success "Build complete!"
}

show_status() {
    check_env_file
    log_info "Production services status:"
    docker-compose $COMPOSE_FILES ps
}

show_help() {
    cat << EOF
${BLUE}KarHubTy Production Docker Management${NC}

Usage: ./docker-prod.sh [command]

Commands:
  ${GREEN}start${NC}     - Build and start all production services
  ${GREEN}stop${NC}      - Stop all running services
  ${GREEN}restart${NC}   - Restart all services
  ${GREEN}logs${NC}      - View logs (use: logs [service_name])
  ${GREEN}status${NC}    - Show services status
  ${GREEN}build${NC}     - Build images without starting
  ${GREEN}clean${NC}     - Remove containers and volumes (⚠️  destructive!)
  ${GREEN}help${NC}      - Show this help message

Examples:
  ./docker-prod.sh start
  ./docker-prod.sh logs backend
  ./docker-prod.sh logs postgres
  ./docker-prod.sh restart
  ./docker-prod.sh stop

Production Notes:
  - Edit ${YELLOW}.env.prod${NC} with your production settings before starting
  - Database backups are stored in ${YELLOW}./backups${NC}
  - Upload files are stored in ${YELLOW}./karhubty-backend/uploads${NC}
  - Use ${YELLOW}docker-compose logs${NC} for debugging
EOF
}

# Main script
case "${1:-help}" in
    start)
        start_production
        ;;
    stop)
        stop_production
        ;;
    restart)
        restart_production
        ;;
    logs)
        view_logs "$2"
        ;;
    status)
        show_status
        ;;
    build)
        build_only
        ;;
    clean)
        clean_volumes
        ;;
    help)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
