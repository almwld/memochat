import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:memochat/core/constants/app_colors.dart';

class ChatLocationData {
  final double latitude, longitude;
  final String address, street, neighborhood, city, state, country, osmType, osmId;
  const ChatLocationData({required this.latitude,required this.longitude,required this.address,this.street='',this.neighborhood='',this.city='',this.state='',this.country='',this.osmType='',this.osmId=''});
}

class ChatLocationPicker extends StatefulWidget {
  const ChatLocationPicker({super.key});
  @override State<ChatLocationPicker> createState()=>_ChatLocationPickerState();
}
class _ChatLocationPickerState extends State<ChatLocationPicker> {
  static const _center=LatLng(15.3694,44.1910);
  final _map=MapController();
  LatLng? _point;
  ChatLocationData? _location;
  bool _loading=false,_locating=false;
  @override void initState(){super.initState();WidgetsBinding.instance.addPostFrameCallback((_)=>_gps());}
  @override void dispose(){_map.dispose();super.dispose();}
  Future<void> _gps() async {
    if(_locating)return; setState(()=>_locating=true);
    try{
      if(!await Geolocator.isLocationServiceEnabled()){_msg('فعّل خدمة الموقع في الهاتف أولاً');return;}
      var p=await Geolocator.checkPermission(); if(p==LocationPermission.denied)p=await Geolocator.requestPermission();
      if(p==LocationPermission.denied||p==LocationPermission.deniedForever){_msg('يلزم السماح للموقع لتحديده');return;}
      final x=await Geolocator.getCurrentPosition(desiredAccuracy:LocationAccuracy.high);
      await _select(LatLng(x.latitude,x.longitude),true);
    }catch(e){debugPrint('chat location gps: $e');_msg('تعذر تحديد موقعك حالياً');}
    finally{if(mounted)setState(()=>_locating=false);}
  }
  Future<void> _select(LatLng point,bool move) async {
    setState(()=>_point=point); if(move)_map.move(point,17); setState(()=>_loading=true);
    try{
      final uri=Uri.https('nominatim.openstreetmap.org','/reverse',{'format':'jsonv2','lat':point.latitude.toStringAsFixed(7),'lon':point.longitude.toStringAsFixed(7),'zoom':'18','addressdetails':'1','accept-language':'ar'});
      final r=await http.get(uri,headers:{'User-Agent':'MemoChat/1.0 (com.memo.app)','Accept':'application/json'}).timeout(const Duration(seconds:8));
      if(r.statusCode!=200)throw StateError('Nominatim ${r.statusCode}');
      final d=jsonDecode(r.body) as Map<String,dynamic>; final a=d['address'] is Map?Map<String,dynamic>.from(d['address']):<String,dynamic>{};
      String v(String k)=>(a[k]??'').toString();
      if(!mounted)return;
      setState(()=>_location=ChatLocationData(latitude:point.latitude,longitude:point.longitude,address:(d['display_name']??_fallback(point)).toString(),street:v('road').isNotEmpty?v('road'):v('pedestrian'),neighborhood:v('neighbourhood').isNotEmpty?v('neighbourhood'):(v('suburb').isNotEmpty?v('suburb'):v('quarter')),city:v('city').isNotEmpty?v('city'):(v('town').isNotEmpty?v('town'):v('village')),state:v('state'),country:v('country'),osmType:(d['osm_type']??'').toString(),osmId:(d['osm_id']??'').toString()));
    }catch(e){debugPrint('chat location reverse: $e');if(mounted)setState(()=>_location=ChatLocationData(latitude:point.latitude,longitude:point.longitude,address:_fallback(point)));}
    finally{if(mounted)setState(()=>_loading=false);}
  }
  String _fallback(LatLng p)=>'الموقع: ${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}';
  void _msg(String s){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('تحديد الموقع'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _locating ? null : _gps,
            icon: _locating
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.my_location),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: _point ?? _center,
                initialZoom: _point == null ? 12 : 17,
                minZoom: 5,
                maxZoom: 19,
                onTap: (_, point) => _select(point, false),
              ),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.memo.app'),
                if (_point != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _point!, width: 52, height: 62, alignment: Alignment.bottomCenter,
                        child: const Icon(Icons.location_pin, color: Colors.red, size: 52),
                      ),
                    ],
                  ),
                const RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap contributors')]),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF121A29) : Colors.white,
              boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12, offset: Offset(0, -2))],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_loading)
                    const LinearProgressIndicator(minHeight: 2)
                  else if (_location != null) ...[
                    Text(_location!.address, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (_location!.street.isNotEmpty) Chip(label: Text(_location!.street)),
                        if (_location!.neighborhood.isNotEmpty) Chip(label: Text(_location!.neighborhood)),
                        if (_location!.city.isNotEmpty) Chip(label: Text(_location!.city)),
                      ],
                    ),
                    Text('${_location!.latitude.toStringAsFixed(6)}, ${_location!.longitude.toStringAsFixed(6)}', textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 11)),
                  ] else
                    const Text('اضغط على الخريطة أو استخدم GPS لتحديد الموقع'),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _location == null || _loading ? null : () => Navigator.pop(context, _location),
                    icon: const Icon(Icons.location_on),
                    label: const Text('إرسال هذا الموقع'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }}