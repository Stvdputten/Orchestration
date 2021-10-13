variable "consul_ip" {
  type = string
  default = "localhost"
  // description = "The consul server ip defined in /etc/hosts"
}

variable "consul_name" {
  type = string
  default = "localhost"
  // description = "The consul server name defined in /etc/hosts"
}

variable "prometheus_hostname" {
  type = string
  // default = "node3.stvdp-107044.sched-serv-pg0.utah.cloudlab.us"
  default = "node3.stvdp-107044.sched-serv-pg0.utah.cloudlab.us"
  // description = "The server ip where prometheus is deployed"
}

job "monitoring" {
  datacenters = ["dc1"]
  type        = "service"

  group "observability" {
    count = 1

    network {
      port "http" {
        static = 9090
      }
      port "grafana" {
        static = 3000
      }
    }

    restart {
      attempts = 3
      delay    = "20s"
      mode     = "delay"
    }

    task "prometheus" {
      driver = "docker"

      constraint {
        attribute = "${attr.unique.hostname}"
        operator = "="
        value = "${var.prometheus_hostname}"
      }

      template {
        data        = <<EOTC
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: 'self'
    consul_sd_configs:
      - server: "consul_server:8500"

    relabel_configs:
      - source_labels: [__meta_consul_service_metadata_external_source]
        target_label: source
        regex: (.*)
        replacement: '$1'
      - source_labels: [__meta_consul_service_id]
        regex: '_nomad-task-([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})-.*'
        target_label:  'task_id'
        replacement: '$1'
      - source_labels: [__meta_consul_tags]
        regex: '.*,prometheus,.*'
        action: keep
      - source_labels: [__meta_consul_tags]
        regex: ',(app|monitoring),'
        target_label:  'group'
        replacement:   '$1'
      - source_labels: [__meta_consul_service]
        target_label: job
      - source_labels: ['__meta_consul_node']
        regex:         '(.*)'
        target_label:  'instance'
        replacement:   '$1'

  - job_name: 'nomad_metrics'

    consul_sd_configs:
      - server: "consul_server:8500"
        services: ['nomad-client', 'nomad']

    relabel_configs:    
    - source_labels: ['__meta_consul_tags']
      regex: '(.*)http(.*)'      
      action: keep

    scrape_interval: 5s    
    metrics_path: /v1/metrics    
    params:      
      format: ['prometheus']

  - job_name: 'cadvisor'

    consul_sd_configs:
      - server: "consul_server:8500"
        services: ['nomad-client', 'nomad']

    relabel_configs:    
    - source_labels: ['__address__']
      separator:     ':'
      regex:         '(.*):(4646|4647|4648)'
      target_label:  '__address__'
      replacement:   '$1:8085'

    scrape_interval: 5s    
    metrics_path: /metrics    
    params:      
      format: ['prometheus']

  - job_name: 'node-exporter'

    consul_sd_configs:
      - server: "consul_server:8500"
        services: ['nomad-client', 'nomad']

    relabel_configs:    
    - source_labels: ['__address__']
      separator:     ':'
      regex:         '(.*):(4646|4647|4648)'
      target_label:  '__address__'
      replacement:   '$1:9100'

    scrape_interval: 5s    
    metrics_path: /metrics    
    params:      
      format: ['prometheus']

EOTC
        destination = "/local/prometheus.yml"
      }
      config {
        image = "prom/prometheus:latest"
        ports = ["http"]
        args = [
          "--config.file=/local/prometheus.yml",
          "--web.enable-admin-api"
        ]
        extra_hosts = [
          "${var.consul_name}:${var.consul_ip}"
        ]
      }

      resources {
        cpu    = 200
        memory = 200
      }

      service {
        name = "prometheus"
        port = "http"
        tags = ["monitoring","prometheus"]

        check {
          name     = "Prometheus HTTP"
          type     = "http"
          path     = "/targets"
          interval = "5s"
          timeout  = "2s"

          check_restart {
            limit           = 2
            grace           = "60s"
            ignore_warnings = false
          }
        }
      }
    }

    task "grafana" {
      driver = "docker"

      config {
        image = "grafana/grafana:latest"
        ports = ["grafana"]
      }

      env {
        GF_LOG_LEVEL          = "DEBUG"
        GF_LOG_MODE           = "console"
        // GF_SERVER_HTTP_PORT   = "${NOMAD_PORT_http}"
        GF_PATHS_PROVISIONING = "/local/grafana/provisioning"
        // GF_PATHS_PROVISIONING = "/local/provisioning"
      }

      template {
        data        = <<EOTC
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    # set server name
    url: {{ env "attr.unique.hostname" }}:9090
    jsonData:
      exemplarTraceIdDestinations:
      - name: traceID
        datasourceUid: tempo
EOTC
        destination = "/local/grafana/provisioning/datasources/ds.yaml"
        // destination = "/local/provisioning/datasources/ds.yaml"
      }
      // https://devopscube.com/setup-grafana-kubernetes/
      // artifact {
      //   source      = "https://raw.githubusercontent.com/cyriltovena/observability-nomad/main/provisioning/dashboard.yaml"
      //   mode        = "file"
      //   destination = "/local/grafana/provisioning/dashboards/dashboard.yaml"
      // }
      artifact {
        source      = "https://raw.githubusercontent.com/stefanprodan/swarmprom/master/grafana/dashboards/swarmprom-nodes-dash.json"
        mode        = "file"
        destination = "/local/grafana/provisioning/dashboards/swarmprom-nodes-dash.json"
      }
      artifact {
        source      = "https://raw.githubusercontent.com/stefanprodan/swarmprom/master/grafana/dashboards/swarmprom-prometheus-dash.json"
        mode        = "file"
        destination = "/local/grafana/provisioning/dashboards/swarmprom-prometheus-dash.json"
      }
      artifact {
        source      = "https://raw.githubusercontent.com/stefanprodan/swarmprom/master/grafana/dashboards/swarmprom-services-dash.json"
        mode        = "file"
        destination = "/local/grafana/provisioning/dashboards/swarmprom-services-dash.json"
      }
      
      artifact {
        source      = "https://raw.githubusercontent.com/cyriltovena/observability-nomad/main/provisioning/dashboard.yaml"
        mode        = "file"
        destination = "/local/grafana/provisioning/dashboards/dashboard.yaml"
      }

      resources {
        cpu    = 100
        memory = 100
      }

      service {
        name = "grafana"
        port = "grafana"
        tags = ["monitoring","grafana"]

        check {
          name     = "Grafana HTTP"
          type     = "http"
          path     = "/api/health"
          interval = "5s"
          timeout  = "2s"

          check_restart {
            limit           = 2
            grace           = "60s"
            ignore_warnings = false
          }
        }
      }
    }
  }
}