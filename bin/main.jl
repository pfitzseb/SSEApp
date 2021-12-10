using HTTP, JSON

const ROUTER = HTTP.Router()

function getItems(req::HTTP.Request)
    headers = [
        "Access-Control-Allow-Origin" => "*",
        "Access-Control-Allow-Methods" => "GET, OPTIONS"
    ]
    if HTTP.method(req) == "OPTIONS"
        return HTTP.Response(200, headers)
    end
    return HTTP.Response(200, headers; body = JSON.json(rand(2)))
end

function events(stream::HTTP.Stream)
    HTTP.setheader(stream, "Access-Control-Allow-Origin" => "*")
    HTTP.setheader(stream, "Access-Control-Allow-Methods" => "GET, OPTIONS")
    HTTP.setheader(stream, "Content-Type" => "text/event-stream")

    if HTTP.method(stream.message) == "OPTIONS"
        return nothing
    end

    @info "GET /api/events"

    HTTP.setheader(stream, "Content-Type" => "text/event-stream")
    HTTP.setheader(stream, "Cache-Control" => "no-cache")
    while isopen(stream)
        @info "ping"
        write(stream, "event: ping\ndata: $(round(Int, time()))\n\n")
        if rand(Bool)
            @info "data"
            write(stream, "data: $(rand())\n\n")
        end
        sleep(1)
    end
    return nothing
end

function root(args...)
    headers = [
        "Access-Control-Allow-Origin" => "*",
        "Access-Control-Allow-Methods" => "GET",
        "Content-Type" => "text/html; charset=UTF-8"
    ]
    return HTTP.Response(200, headers; body = """
    <html>
    <head>
        <meta charset="UTF-8">
        <title>Server-sent events demo</title>
    </head>
    <body>
        <h3>Fetched items:</h3>
        <ul id="list"></ul>
    </body>
    <script>
        const evtSource = new EventSource("/api/events")
        evtSource.onmessage = async function (event) {
            const newElement = document.createElement("li");
            const eventList = document.getElementById("list");
            if (parseFloat(event.data) > 0.5) {
                const r = await fetch("/api/getItems")
                if (r.ok) {
                    const body = await r.json()
                    newElement.textContent = body;
                    eventList.appendChild(newElement);
                }
            }
        }
        evtSource.addEventListener("ping", function(event) {
            console.log('ping:', event.data)
        });
    </script>
    </html>
    """)
end

HTTP.@register(ROUTER, "GET", "/index", root)
HTTP.@register(ROUTER, "GET", "/api/getItems", getItems)
HTTP.@register(ROUTER, "/api/events", HTTP.Handlers.StreamHandlerFunction(events))

HTTP.serve(ROUTER, "0.0.0.0", 8081)
