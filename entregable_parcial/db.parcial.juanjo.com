$TTL 86400
@   IN  SOA maestro.empresa.local. admin.empresa.local. (
        2026030303 ; serial (incrementar al editar)
        3600
        1800
        604800
        86400 )
@   IN  NS  maestro.empresa.local.
@   IN  A   192.168.56.10
www IN  CNAME @
