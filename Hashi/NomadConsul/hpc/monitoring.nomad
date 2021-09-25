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

job "monitoring" {
  datacenters = ["dc1"]
  type        = "service"

  group "prometheus" {
    count = 1

    network {
      port "http" {
        static = 9090
      }
      // port "cadvisor" {
      //   static = 8080
      // }
    }

    restart {
      attempts = 3
      delay    = "20s"
      mode     = "delay"
    }

    task "prometheus" {
      driver = "docker"

      template {
        data        = <<EOTC
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: 'self'
    consul_sd_configs:
# use the server where you have a consul setup
      - server: "consul_server:8500"
  #    - server: '${attr.unique.network.ip-address}:8500'
#       - server: '{{ env "NOMAD_IP_prometheus_ui" }}:8500'
#      - server: '{{ env "attr.unique.network.ip-address" }}:8500'

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
      # - server: 'localhost:8500'
      # - server: '{{ env "" }}:8500'
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

    // task "node-exporter" {
    //   driver = "docker"

    //   config {
    //     image = "prom/node-exporter:latest"
    //     ports = ["http"]
    //     args = [
    //       "--web.enable-admin-api",
    //       "--web.enable-admin-api"
    //     ]
    //   }

    //   resources {
    //     cpu    = 200
    //     memory = 200
    //   }

    //   service {
    //     name = "node-exporter"
    //     port = "http"
    //     tags = ["monitoring","node-exporter"]

    //     // check {
    //     //   name     = "Prometheus HTTP"
    //     //   type     = "http"
    //     //   path     = "/targets"
    //     //   interval = "5s"
    //     //   timeout  = "2s"

    //     //   check_restart {
    //     //     limit           = 2
    //     //     grace           = "60s"
    //     //     ignore_warnings = false
    //     //   }
    //     // }
    //   }
    // }

    // task "cadvisor" {
    //   driver = "docker"

    //   config {
    //     image = "gcr.io/cadvisor/cadvisor"
    //     ports = ["cadvisor"]
    //     volumes = [
    //       "/:/rootfs:ro",
    //       "/var/run:/var/run:rw",
    //       "/sys:/sys:ro",
    //       "/var/lib/docker/:/var/lib/docker:ro",
    //       "/cgroup:/cgroup:ro"
    //     ]
    //   }

    //   resources {
    //     cpu    = 200
    //     memory = 200
    //   }

    //   service {
    //     name = "cadvisor"
    //     port = "cadvisor"
    //     tags = ["monitoring", "cadvisor"]

    //     check {
    //       type     = "http"
    //       path     = "/"
    //       interval = "5s"
    //       timeout  = "2s"

    //       check_restart {
    //         limit           = 2
    //         grace           = "60s"
    //         ignore_warnings = false
    //       }
    //     }
    //   }
    // }

//     task "grafana" {
//       driver = "docker"

//       config {
//         image = "grafana/grafana:latest"
//         ports = ["http"]
//       }

//       env {
//         GF_LOG_LEVEL          = "DEBUG"
//         GF_LOG_MODE           = "console"
//         GF_SERVER_HTTP_PORT   = "${NOMAD_PORT_http}"
//         GF_PATHS_PROVISIONING = "/local/grafana/provisioning"
//         // GF_PATHS_PROVISIONING = "/local/provisioning"
//       }

//       template {
//         data        = <<EOTC
// apiVersion: 1
// datasources:
//   - name: Prometheus
//     type: prometheus
//     access: proxy
//     # set server name
//     url: http://node1.stvdp-101469.sched-serv-pg0.utah.cloudlab.us:9090
//     jsonData:
//       exemplarTraceIdDestinations:
//       - name: traceID
//         datasourceUid: tempo
// #  - name: Tempo
// #    type: tempo
// #    access: proxy
// #    url: http://tempo.service.dc1.consul:3400
// #    uid: tempo
// #  - name: Loki
// #    type: loki
// #    access: proxy
// #    url: http://loki.service.dc1.consul:3100
// #    jsonData:
// #      derivedFields:
// #        - datasourceUid: tempo
// #          matcherRegex: (?:traceID|trace_id)=(\w+)
// #          name: TraceID
// #          url: $$${__value.raw}
// EOTC
//         destination = "/local/grafana/provisioning/datasources/ds.yaml"
//         // destination = "/local/provisioning/datasources/ds.yaml"
//       }
//       // https://devopscube.com/setup-grafana-kubernetes/
//       // artifact {
//       //   source      = "https://raw.githubusercontent.com/cyriltovena/observability-nomad/main/provisioning/dashboard.yaml"
//       //   mode        = "file"
//       //   destination = "/local/grafana/provisioning/dashboards/dashboard.yaml"
//       // }

//       artifact {
//         source      = "github.com/burdandrei/nomad-monitoring/examples/grafana/provisioning"
//         destination = "local/grafana/provisioning/"
//       }

//       artifact {
//         source      = "github.com/burdandrei/nomad-monitoring/examples/grafana/dashboards"
//         destination = "local/dashboards"
//       }

//       resources {
//         cpu    = 100
//         memory = 100
//       }

//       service {
//         name = "grafana"
//         port = "http"
//         tags = ["monitoring","grafana"]

//         check {
//           name     = "Grafana HTTP"
//           type     = "http"
//           path     = "/api/health"
//           interval = "5s"
//           timeout  = "2s"

//           check_restart {
//             limit           = 2
//             grace           = "60s"
//             ignore_warnings = false
//           }
//         }
//       }
//     }
  }
}