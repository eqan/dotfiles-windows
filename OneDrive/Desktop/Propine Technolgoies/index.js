const fs = require('fs');
const csv = require('csv-parser');
const request = require('request');
const dotenv = require('dotenv');
dotenv.config();

function getTokenPrice(token) {
  return new Promise((resolve, reject) => {
    request(`https://min-api.cryptocompare.com/data/price?fsym=${token}&tsyms=USD&api_key=${process.env.API_KEY}`, (error, response, body) => {
      if (error) {
        reject(error);
      } else if (response.statusCode !== 200) {
        reject(new Error(`Invalid status code: ${response.statusCode}`));
      } else {
        resolve(JSON.parse(body).USD);
      }
    });
  });
}

async function getPortfolioValue(transactions) {
  // Dictionary to store the current portfolio value for each token
  const portfolioValue = {};
  // console.log(transactions)
  for (const transaction of transactions) {
    try {
      // Get the current price for the token in USD
      const price = await getTokenPrice(transaction.token);
      const token = transaction.token; 
      // console.log(price)
      // Update the portfolio value for the token
      if (transaction.transaction_type === 'DEPOSIT') {
        portfolioValue[transaction.token] = (portfolioValue[transaction.token] || 0) + transaction.amount * price;
      } else if (transaction.transaction_type === 'WITHDRAWAL') {
        portfolioValue[transaction.token] = (portfolioValue[transaction.token] || 0) - transaction.amount * price;
      }
    } catch (error) {
      console.error(`Error getting price for ${transaction.token}: ${error.message}`);
    }
  }

  return portfolioValue;
}


async function main() {
  const transactions = [];

  // Read the CSV file and store the transactions in an array
  fs.createReadStream('data/transactions.csv')
    .pipe(csv())
    .on('data', (row) => {
      transactions.push({
        timestamp: row.timestamp,
        transaction_type: row.transaction_type,
        token: row.token,
        amount: parseFloat(row.amount),
      });
    })
    .on('end', async () => {
      // Get the portfolio value for each token
      const portfolioValue = await getPortfolioValue(transactions);

      // Print the portfolio value for each token
      for (const [token, value] of Object.entries(portfolioValue)) {
        console.log(`${token}: ${value.toFixed(2)} USD`);
      }
    });
}

main();
