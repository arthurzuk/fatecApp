import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:async';
import 'dart:io';

import 'package:pie_chart/pie_chart.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

import 'dart:convert' as convert;
import 'globals.dart' as globals;

void main() {
  runApp(MyApp());
}

Future<void> loadAssets() async {
  final DataStorage dataStorage = new DataStorage();

  //getData();

  final asset = await rootBundle.loadString('assets/json/coronaData.txt');
  final asset2 = await rootBundle.loadString('assets/json/geoJason.json');

  final tempo = convert.jsonDecode(asset) as List<dynamic>;
  final tempo2 = convert.jsonDecode(asset2) as Map<String, dynamic>;
  globals.covidData = tempo;
  globals.geo = tempo2["geometries"][0]["coordinates"];
  await dataStorage.readData();
  await dataStorage.writeData();
  createPolygon();
}

Future<Map<String, dynamic>> getData() async {
  var response = await http.get(
      Uri.parse(
          'https://api.brasil.io/v1/dataset/covid19/caso/data/?is_last=True&state=SP'),
      headers: {
        'Authorization': "Token ffb240f5a91320a6a7f386bf21d076994800a7b0"
      });
  if (response.statusCode == 200) {
    var jsonResponse =
        //convert.jsonDecode(response.body)
        convert.jsonDecode(convert.utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
    return jsonResponse;
  } else {
    print('Request failed with status: ${response.statusCode}.');
    throw ('error');
  }
}

void createPolygon() {
  final Set<Polygon> polys = new Set();
  //final Set<Polygon> polys2 = new Set();

  var city;
  int dex = 0;
  double mod = 0;
  double mod1 = 0;
  double mod2 = 0;
  final String tipo;
  double med = 0;
  switch (globals.mapType) {
    case ('Contágio'):
      tipo = 'confirmed_per_100k_inhabitants';
      med = 10000;
      break;
    case ('Dose 1'):
      tipo = 'dose1';
      break;
    case ('Dose 2'):
      tipo = 'dose2';
      break;
    default:
      tipo = 'death_rate';
      med = 0.05;
      break;
  }

  if (tipo == 'death_rate' || tipo == 'Contágio') {
    for (List state in globals.geo) {
      List<LatLng> polygonCoords = [];
      for (List coor in state[0]) {
        polygonCoords.add(LatLng(coor[1].toDouble(), coor[0].toDouble()));
      }
      city = globals.covidData[dex];

      mod = city[tipo] / med;
      if (mod.floor() >= 1) mod = 1;

      mod1 = 2 * 255 * mod;
      if (mod1 > 255) mod1 = 255;

      mod2 = 2 * 255 * (1 - mod);
      if (mod2 > 255) mod2 = 255;
      polys.add(Polygon(
          polygonId: PolygonId(city['city']),
          points: polygonCoords,
          fillColor: new Color.fromRGBO(mod1.floor(), mod2.floor(), 0, 1),
          strokeWidth: 1,
          strokeColor: Colors.black,
          zIndex: 0));
      dex++;
    }
  } else {
    for (List state in globals.geo) {
      List<LatLng> polygonCoords = [];
      for (List coor in state[0]) {
        polygonCoords.add(LatLng(coor[1].toDouble(), coor[0].toDouble()));
      }
      city = globals.covidData[dex];

      mod = city[tipo] / (city['estimated_population'] * 0.2);
      if (mod.floor() >= 1) mod = 1;

      mod1 = 2 * 255 * mod;
      if (mod1 > 255) mod1 = 255;

      mod2 = 2 * 255 * (1 - mod);
      if (mod2 > 255) mod2 = 255;
      polys.add(Polygon(
          polygonId: PolygonId(city['city']),
          points: polygonCoords,
          fillColor: new Color.fromRGBO(mod1.floor(), mod2.floor(), 0, 1),
          strokeWidth: 1,
          strokeColor: Colors.black,
          zIndex: 0));
      dex++;
    }
  }
  globals.poly = polys;
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: MyHomePage(key: UniqueKey(), title: 'Home'));
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({required Key key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final DataStorage dataStorage = new DataStorage();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
        future: loadAssets(),
        builder: (BuildContext contex, AsyncSnapshot<void> snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.waiting:
              return Text("Loading...");
            default:
              return MyMapPage(key: UniqueKey(), title: 'Map');
          }
        });
  }
}

class MyMapPage extends StatefulWidget {
  MyMapPage({required Key key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyMapPageState createState() => _MyMapPageState();
}

class _MyMapPageState extends State<MyMapPage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic> dropdownValue = globals.citySelect;
  String dropdownValue2 = globals.mapType.toString();
  Completer<GoogleMapController> _controller = Completer();
  TabController? _tabController;
  static final CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(-23.5505, -46.6333),
    zoom: 8.4746,
  );

  @override
  void initState() {
    super.initState();
    _tabController = new TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize:
            Size.fromHeight(MediaQuery.of(context).size.height * 0.07),
        child: AppBar(
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              new Tab(
                text: globals.citySelect['city'],
              ),
              new Tab(
                text: '',
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: Column(
          children: <Widget>[
            SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height * 0.20,
                child:
                    TabBarView(controller: _tabController, children: <Widget>[
                  new Card(
                      child: Text('Casos: ' +
                          globals.citySelect['confirmed'].toString() +
                          '\nTaxa de infecção: ' +
                          (globals.citySelect[
                                      'confirmed_per_100k_inhabitants'] /
                                  1000)
                              .toString() +
                          '\nMortes: ' +
                          globals.citySelect['deaths'].toString() +
                          '\nTaxa de mortalidade: ' +
                          globals.citySelect['death_rate'].toString() +
                          '\nPopulação estimada: ' +
                          globals.citySelect['estimated_population']
                              .toString() +
                          '\nÚltima atualização: ' +
                          globals.citySelect['date'].toString() +
                          '\nDose 1: ' +
                          globals.citySelect['dose1'].toString())),
                  new Card(
                      child: Row(
                    children: <Widget>[
                      PieChart(
                          dataMap: {
                            "": (globals.citySelect["estimated_population"] -
                                    globals.citySelect["dose1"])
                                .toDouble(),
                            "Vacinada": (globals.citySelect["dose1"]).toDouble()
                          },
                          centerText: "Dose 1",
                          legendOptions: LegendOptions(
                            showLegends: false,
                          ),
                          chartValuesOptions: ChartValuesOptions(
                            showChartValuesInPercentage: true,
                          )),
                      PieChart(
                          dataMap: {
                            "": (globals.citySelect["estimated_population"] -
                                    globals.citySelect["dose2"])
                                .toDouble(),
                            "Vacinada": (globals.citySelect["dose2"]).toDouble()
                          },
                          centerText: "Dose 2",
                          legendOptions: LegendOptions(
                            showLegends: false,
                          ),
                          chartValuesOptions: ChartValuesOptions(
                            showChartValuesInPercentage: true,
                          ))
                    ],
                  )),
                ])),
            SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height * 0.57,
              child: GoogleMap(
                polygons: globals.poly,
                scrollGesturesEnabled: true,
                zoomControlsEnabled: true,
                mapType: MapType.normal,
                initialCameraPosition: _kGooglePlex,
                onMapCreated: (GoogleMapController controller) {
                  _controller.complete(controller);
                },
              ),
            ),
            DropdownButton<String>(
              value: dropdownValue['city'],
              icon: const Icon(Icons.arrow_downward),
              iconSize: 24,
              elevation: 16,
              style: const TextStyle(color: Colors.deepPurple),
              underline: Container(
                height: 2,
                color: Colors.deepPurpleAccent,
              ),
              onChanged: (String? newValue) {
                setState(() {
                  var unselectedPoly = globals.poly.firstWhere((poly) =>
                      poly.polygonId == PolygonId(dropdownValue['city']));

                  var selectedPoly = globals.poly.firstWhere(
                      (poly) => poly.polygonId == PolygonId(newValue!));

                  unselectedPoly = unselectedPoly.copyWith(
                      strokeColorParam: Colors.black, zIndexParam: 0);
                  globals.poly.removeWhere(
                      (poly) => poly.polygonId == PolygonId(newValue!));
                  globals.poly.add(unselectedPoly);

                  selectedPoly = selectedPoly.copyWith(
                      strokeColorParam: Colors.white, zIndexParam: 1);
                  globals.poly.removeWhere(
                      (poly) => poly.polygonId == PolygonId(newValue!));
                  globals.poly.add(selectedPoly);

                  dropdownValue = globals.covidData
                      .firstWhere((item) => item['city'] == newValue!);
                  globals.citySelect = dropdownValue;
                  moveCamera(LatLng(
                      dropdownValue['coor'][1], dropdownValue['coor'][0]));
                });
              },
              items:
                  globals.cities.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
            DropdownButton<String>(
              value: dropdownValue2,
              icon: const Icon(Icons.arrow_downward),
              iconSize: 24,
              elevation: 16,
              style: const TextStyle(color: Colors.deepPurple),
              underline: Container(
                height: 2,
                color: Colors.deepPurpleAccent,
              ),
              onChanged: (String? newValue) {
                setState(() {
                  dropdownValue2 = newValue!;
                  globals.mapType = newValue;
                  createPolygon();
                });
              },
              items: <String>['Mortalidade', 'Contágio', 'Dose 1', 'Dose 2']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            )
          ],
        ),
      ),
    );
  }

  moveCamera(LatLng coor) async {
    GoogleMapController con = await _controller.future;
    con.animateCamera(
        CameraUpdate.newCameraPosition(CameraPosition(target: coor, zoom: 9)));
  }
}

//data tab

class MyDatPage extends StatefulWidget {
  MyDatPage({required Key key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyDatPageState createState() => _MyDatPageState();
}

class _MyDatPageState extends State<MyDatPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(child: Text("teste2")),
    );
  }
}

class DataStorage {
  Future<String> get _localPath async {
    final directory = await getApplicationSupportDirectory();
    print(directory.path);
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    final tempF = File('$path/data.txt');
    if (await tempF.exists()) {
      print("file exist");
      return tempF;
    } else {
      print("file don't exist");
      print("igothere");
      tempF.writeAsString(convert.jsonEncode(globals.covidData));
      print("finished writing");
      return tempF;
    }
  }

  Future<int> readData() async {
    //try {
    final file = await _localFile;

    String contents = await file.readAsString();
    var localJson = convert.jsonDecode(contents) as List<dynamic>;
    globals.covidData = localJson;
    return 1;
    //} catch (e) {
    //  print("Erro ao ler json.");
    //  return 0;
    // }
  }

  Future<File> writeData() async {
    final file = await _localFile;
    final encodedJson = convert.jsonEncode(globals.covidData);
    // Write the file
    return file.writeAsString('$encodedJson');
  }
}
