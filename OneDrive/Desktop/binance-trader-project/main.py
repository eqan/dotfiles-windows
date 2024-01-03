from fastapi import FastAPI, __version__, Request
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse
from http import HTTPStatus
from binance.client import Client
from pydantic import BaseModel

class Data(BaseModel):
    message: str

# Initialize Binance Client
BINANCE_API_KEY = 'YOUR_BINANCE_API_KEY'
BINANCE_API_SECRET = 'YOUR_BINANCE_API_SECRET'
client = Client(BINANCE_API_KEY, BINANCE_API_SECRET)

def execute_trade(action):
    symbol = 'BTCUSDT'
    if action == 'BUY':
        order = client.order_market_buy(symbol=symbol, quantity=0.001)
    elif action == 'SELL':
        order = client.order_market_sell(symbol=symbol, quantity=0.001)
    print(f"Executed {action} order: {order}")

def handler(req, res):
    try:
        body = req.body
        data = Data(**body)
        signal_message = data.message

        if "This is NOT a BUY signal!" not in signal_message and "BUY" in signal_message:
            execute_trade('BUY')
        elif "This is NOT a SELL signal!" not in signal_message and "SELL" in signal_message:
            execute_trade('SELL')

        res.status = HTTPStatus.OK
        return {"status": "OK"}
    except Exception as e:
        res.status = HTTPStatus.INTERNAL_SERVER_ERROR
        return {"status": "Error", "message": str(e)}


app = FastAPI()
app.mount("/static", StaticFiles(directory="static"), name="static")

html = f"""
<!DOCTYPE html>
<html>
    <head>
        <title>FastAPI on Vercel</title>
        <link rel="icon" href="/static/favicon.ico" type="image/x-icon" />
    </head>
    <body>
        <div class="bg-gray-200 p-4 rounded-lg shadow-lg">
            <h1>Hello from FastAPI@{__version__}</h1>
            <ul>
                <li><a href="/docs">/docs</a></li>
                <li><a href="/redoc">/redoc</a></li>
            </ul>
            <p>Powered by <a href="https://vercel.com" target="_blank">Vercel</a></p>
        </div>
    </body>
</html>
"""

@app.get("/")
async def root():
    return HTMLResponse(html)

@app.post("/webhook")
async def webhook_listener(request: Request):
    data = await request.json()
    if not data:
        return {"status": "OK"}
    try:
        # Extract the signal/message from PineScript
        signal_message = data['message']

        if "This is NOT a BUY signal!" not in signal_message and "BUY" in signal_message:
            execute_trade('BUY')
        elif "This is NOT a SELL signal!" not in signal_message and "SELL" in signal_message:
            execute_trade('SELL')

        return {"status": "OK"}
    except Exception as e:
        print(f"Error: {e}")
        return {"status": "Error", "message": str(e)}