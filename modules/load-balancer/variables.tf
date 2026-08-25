# Load Balancer Module Variables

variable "compartment_ocid" {
  description = "Compartment OCID for load balancer resources"
  type        = string
}

variable "create_public_lb" {
  description = "Create public load balancer"
  type        = bool
  default     = true
}

variable "public_lb_shape" {
  description = "Public LB shape (flexible or fixed)"
  type        = string
  default     = "flexible"
}

variable "public_lb_min_bw" {
  description = "Public LB minimum bandwidth (Mbps)"
  type        = number
  default     = 100
}

variable "public_lb_max_bw" {
  description = "Public LB maximum bandwidth (Mbps)"
  type        = number
  default     = 8000
}

variable "create_private_lb" {
  description = "Create private load balancer"
  type        = bool
  default     = true
}

variable "private_lb_shape" {
  description = "Private LB shape (flexible or fixed)"
  type        = string
  default     = "flexible"
}

variable "private_lb_min_bw" {
  description = "Private LB minimum bandwidth (Mbps)"
  type        = number
  default     = 100
}

variable "private_lb_max_bw" {
  description = "Private LB maximum bandwidth (Mbps)"
  type        = number
  default     = 4000
}

variable "public_subnet_ocids" {
  description = "Public subnet OCIDs for public LB"
  type        = map(string)
}

variable "private_subnet_ocids" {
  description = "Private subnet OCIDs for private LB"
  type        = map(string)
}

variable "backend_servers" {
  description = "Backend server private IPs"
  type        = map(list(string))
  default     = {}
}

variable "backend_port" {
  description = "Backend server port"
  type        = number
  default     = 8080
}

variable "health_check_protocol" {
  description = "Health check protocol (HTTP, TCP)"
  type        = string
  default     = "HTTP"
}

variable "health_check_path" {
  description = "Health check path (for HTTP)"
  type        = string
  default     = "/health"
}

variable "health_check_port" {
  description = "Health check port"
  type        = number
  default     = 8080
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

variable "ssl_certificate_id" {
  description = "OCI Certificates service certificate OCID for HTTPS"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
variable "additional_routes" {
  description = "Additional named service routes on the public LB: route name -> route config. Creates one backend set + listener per name without touching the default backend set."
  type = map(object({
    listener_port            = number
    protocol                 = optional(string, "HTTP")
    backend_port             = number
    health_check_protocol    = optional(string, "HTTP")
    health_check_path        = optional(string, "/")
    health_check_port        = optional(number)
    health_check_interval_ms = optional(number, 30000)
    health_check_timeout_ms  = optional(number, 5000)
    health_check_retries     = optional(number, 3)
  }))
  default = {}
}

variable "route_backends" {
  description = "Backend server private IPs per additional route name"
  type        = map(list(string))
  default     = {}
}
