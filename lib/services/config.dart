// lib/config.dart

// 1. ANG IYONG AKTIBONG NGROK TUNNEL URL
// Tiyaking WALANG slash (/) sa pinakadulo ng string na ito.
// Dito natin ilalagay ang link para isang baguhan lang kung sakaling magbago ang Ngrok
const String baseUrl = "https://discern-generous-ocelot.ngrok-free.dev";
// 2. GLOBAL NETWORK HEADERS PARA SA ONLINE REQUESTS
// Nilalagpasan nito ang interstitial warning page ng Ngrok at pinipilit ang Laravel na magbalik ng JSON.
Map<String, String> networkHeaders = {
  'Content-Type': 'application/json',
  'Accept': 'application/json',
  'ngrok-skip-browser-warning': 'true',
};
