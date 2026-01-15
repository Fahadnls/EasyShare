// class NearbyService {
//   final Strategy strategy = Strategy.P2P_CLUSTER;

//   Future<void> startAdvertising(String username) async {
//     await Nearby().startAdvertising(
//       username,
//       strategy,
//       onConnectionInitiated: (id, info) {
//         Nearby().acceptConnection(
//           id,
//           onPayLoadRecieved: (endid, payload) {},
//           onPayloadTransferUpdate: (endid, update) {},
//         );
//       },
//       onConnectionResult: (id, status) {},
//       onDisconnected: (id) {},
//     );
//   }

//   Future<void> startDiscovery() async {
//     await Nearby().startDiscovery(
//       "username",
//       strategy,
//       onEndpointFound: (id, name, serviceId) {
//         Nearby().requestConnection(
//           "sender",
//           id,
//           onConnectionInitiated: (id, info) {
//             Nearby().acceptConnection(
//               id,
//               onPayLoadRecieved: (endid, payload) {},
//               onPayloadTransferUpdate: (endid, update) {},
//             );
//           },
//           onConnectionResult: (id, status) {},
//           onDisconnected: (id) {},
//         );
//       },
//       onEndpointLost: (id) {},
//     );
//   }

//   Future<void> sendFile(String endpointId, String path) async {
//     await Nearby().sendFilePayload(endpointId, path);
//   }
// }
