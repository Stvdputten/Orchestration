job "grafana" {
  datacenters = ["dc1"]
  type        = "service"

  group "grafana" {
    count = 1

    network {
      port "http" {
        static = 3000
      }
    }

    restart {
      attempts = 3
      delay    = "20s"
      mode     = "delay"
    }

    task "grafana" {
      driver = "docker"

      config {
        image = "grafana/grafana:latest"
        ports = ["http"]
      }

      env {
        GF_LOG_LEVEL          = "DEBUG"
        GF_LOG_MODE           = "console"
        GF_SERVER_HTTP_PORT   = "${NOMAD_PORT_http}"
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
    url: http://node1.stvdp.sched-serv-pg0.utah.cloudlab.us:9090
    jsonData:
      exemplarTraceIdDestinations:
      - name: traceID
        datasourceUid: tempo
#  - name: Tempo
#    type: tempo
#    access: proxy
#    url: http://tempo.service.dc1.consul:3400
#    uid: tempo
#  - name: Loki
#    type: loki
#    access: proxy
#    url: http://loki.service.dc1.consul:3100
#    jsonData:
#      derivedFields:
#        - datasourceUid: tempo
#          matcherRegex: (?:traceID|trace_id)=(\w+)
#          name: TraceID
#          url: $$${__value.raw}
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
        source      = "github.com/burdandrei/nomad-monitoring/examples/grafana/provisioning"
        destination = "local/grafana/provisioning/"
      }

      artifact {
        source      = "github.com/burdandrei/nomad-monitoring/examples/grafana/dashboards"
        destination = "local/dashboards"
      }

      resources {
        cpu    = 100
        memory = 100
      }

      service {
        name = "grafana"
        port = "http"
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