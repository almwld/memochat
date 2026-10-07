import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;

class _DedicationConfig {
  static const recipient='إلى ميمو', from='من فلانتشتاين';
  static const body='في كل نجمة أراها،\nأراكِ أنتِ.\n\nفي كل قلب ينبض،\nقلبك يسكنني.\n\nأنتِ الحكاية التي لم أكتبها بعد،\nوالبحر الذي لم أبحره بعد.\n\nأنتِ ميمو...\nوأنتِ كل شيء.';
  static const closing='أحبكِ', finalLine='إلى ميمو، دائمًا.', gold=Color(0xFFFFD700), pink=Color(0xFFFF6B9D);
}
class MemoDedicationScreen extends StatefulWidget{const MemoDedicationScreen({super.key});@override State<MemoDedicationScreen> createState()=>_MemoDedicationScreenState();}
class _MemoDedicationScreenState extends State<MemoDedicationScreen> with TickerProviderStateMixin{
 late final AnimationController bg,stars,hearts,petals,pulse,beam,entrance; late final List<_Star> ss;late final List<_Heart> hh;late final List<_Petal> pp;
 @override void initState(){super.initState();final r=Random(7047);ss=List.generate(80,(_)=>_Star(r.nextDouble(),r.nextDouble(),.6+r.nextDouble()*2.4,r.nextDouble()*2*pi,.4+r.nextDouble()*1.8,(r.nextDouble()-.5)*.02));hh=List.generate(25,(_)=>_Heart(r.nextDouble(),1+r.nextDouble()*.8,10+r.nextDouble()*22,.1+r.nextDouble()*.22,.02+r.nextDouble()*.05,r.nextDouble()*2*pi,320+r.nextDouble()*45));pp=List.generate(15,(_)=>_Petal(r.nextDouble(),-.2-r.nextDouble()*.5,6+r.nextDouble()*10,.06+r.nextDouble()*.12,.5+r.nextDouble()*2,.03+r.nextDouble()*.06,r.nextDouble()*2*pi));bg=AnimationController(vsync:this,duration:const Duration(seconds:20))..repeat();stars=AnimationController(vsync:this,duration:const Duration(seconds:5))..repeat();hearts=AnimationController(vsync:this,duration:const Duration(seconds:22))..repeat();petals=AnimationController(vsync:this,duration:const Duration(seconds:18))..repeat();pulse=AnimationController(vsync:this,duration:const Duration(milliseconds:1800))..repeat(reverse:true);beam=AnimationController(vsync:this,duration:const Duration(seconds:6))..repeat();entrance=AnimationController(vsync:this,duration:const Duration(milliseconds:1400))..forward();HapticFeedback.mediumImpact();}
 @override void dispose(){for(final c in [bg,stars,hearts,petals,pulse,beam,entrance])c.dispose();super.dispose();}
 @override Widget build(BuildContext c){final z=MediaQuery.sizeOf(c);return Scaffold(backgroundColor:Colors.black,body:Semantics(namesRoute:true,label:'إهداء خاص إلى ميمو',child:Stack(children:[AnimatedBuilder(animation:bg,builder:(_,__) {final t=bg.value;return Container(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment(-1+sin(t*2*pi)*.6,-1+cos(t*2*pi)*.6),end:Alignment(1-sin(t*2*pi)*.6,1-cos(t*2*pi)*.6),colors:const[Color(0xFF0D0221),Color(0xFF2A0845),Color(0xFF4A0E3C),Color(0xFF1A0B2E)])));}),RepaintBoundary(child:AnimatedBuilder(animation:stars,builder:(_,__)=>CustomPaint(size:z,painter:_StarsPainter(ss,stars.value)))),RepaintBoundary(child:AnimatedBuilder(animation:petals,builder:(_,__)=>CustomPaint(size:z,painter:_PetalsPainter(pp,petals.value)))),RepaintBoundary(child:AnimatedBuilder(animation:hearts,builder:(_,__)=>CustomPaint(size:z,painter:_HeartsPainter(hh,hearts.value)))),RepaintBoundary(child:AnimatedBuilder(animation:beam,builder:(_,__)=>CustomPaint(size:z,painter:_BeamPainter(beam.value)))),
          CustomPaint(size:z,painter:_VignettePainter()),
          IgnorePointer(child:Align(alignment:Alignment.bottomCenter,child:Padding(padding:const EdgeInsets.only(bottom:8),child:Text('MemoChat • إهداء خاص',style:TextStyle(color:Colors.white24,fontSize:9,letterSpacing:1.2))))),
          SafeArea(child:Stack(children:[
          PositionedDirectional(top:12,end:16,child:_CloseButton()),
          FadeTransition(opacity:entrance,child:SlideTransition(position:Tween(begin:const Offset(0,.15),end:Offset.zero).animate(CurvedAnimation(parent:entrance,curve:Curves.easeOutCubic)),child:SingleChildScrollView(padding:const EdgeInsets.fromLTRB(24,48,24,30),child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:560),child:Column(children:[const SizedBox(height:12),
            const _MemoIdentity(),
            const SizedBox(height:12),
            _GlassLabel(),
            const SizedBox(height:26),
            _MemoHeart(controller:pulse),
            const SizedBox(height:34),const _TypewriterText(text:_DedicationConfig.recipient,style:TextStyle(fontSize:36,color:_DedicationConfig.gold,fontWeight:FontWeight.w700,letterSpacing:2.2),charsPerSecond:4,delay:Duration(milliseconds:600)),const SizedBox(height:20),const _GoldenDivider(delay:Duration(milliseconds:1800)),
            const SizedBox(height:28),
            const _MemoryCaption(),
            const SizedBox(height:26),
            _LetterCard(
              child: const _TypewriterText(
                text:_DedicationConfig.body,
                style:TextStyle(fontSize:19,color:Color(0xFFF9F5FA),height:2.05,letterSpacing:.45,fontWeight:FontWeight.w400),
                charsPerSecond:18,
                delay:Duration(milliseconds:2600),
              ),
            ),
            const SizedBox(height:42),const _PulsingClosing(text:_DedicationConfig.closing,delay:Duration(milliseconds:11000)),const SizedBox(height:22),const _FinalLine(delay:Duration(milliseconds:14500)),const SizedBox(height:56),const _TypewriterText(text:_DedicationConfig.from,style:TextStyle(fontSize:21,color:Color(0xFFFFE6A3),fontStyle:FontStyle.italic,fontWeight:FontWeight.w500),charsPerSecond:3,delay:Duration(milliseconds:13000)),const SizedBox(height:54),
            _CloseHint(),
            const SizedBox(height:24),
          ])))))]))]));}
}

class _MemoIdentity extends StatelessWidget{const _MemoIdentity();@override Widget build(BuildContext c)=>Semantics(label:'MemoChat',child:Row(mainAxisSize:MainAxisSize.min,mainAxisAlignment:MainAxisAlignment.center,children:[CustomPaint(size:const Size(34,28),painter:_MemoMarkPainter()),const SizedBox(width:9),Text('MemoChat',style:TextStyle(color:Colors.white.withOpacity(.72),fontSize:13,fontWeight:FontWeight.w600,letterSpacing:1.1))]));}
class _MemoMarkPainter extends CustomPainter{@override void paint(Canvas c,Size s){final p=Paint()..color=_DedicationConfig.pink;final a=RRect.fromRectAndRadius(Rect.fromLTWH(1,2,25,18),const Radius.circular(7));c.drawRRect(a,p);final b=Path()..moveTo(7,18)..lineTo(5,25)..lineTo(13,19)..close();c.drawPath(b,p);final q=Paint()..color=_DedicationConfig.gold;final r=RRect.fromRectAndRadius(Rect.fromLTWH(11,8,22,16),const Radius.circular(6));c.drawRRect(r,q);final t=Path()..moveTo(26,22)..lineTo(29,27)..lineTo(22,23)..close();c.drawPath(t,q);}@override bool shouldRepaint(_)=>false;}
class _FinalLine extends StatefulWidget{final Duration delay;const _FinalLine({required this.delay});@override State<_FinalLine> createState()=>_FinalLineState();}
class _FinalLineState extends State<_FinalLine> with SingleTickerProviderStateMixin{late final AnimationController c;bool visible=false;@override void initState(){super.initState();c=AnimationController(vsync:this,duration:const Duration(milliseconds:900));Future.delayed(widget.delay,(){if(mounted){setState(()=>visible=true);c.forward();}});}@override void dispose(){c.dispose();super.dispose();}@override Widget build(BuildContext x)=>AnimatedBuilder(animation:c,builder:(_,__)=>Opacity(opacity:c.value,child:Transform.translate(offset:Offset(0,12*(1-c.value)),child:visible?const Text(_DedicationConfig.finalLine,style:TextStyle(color:Color(0xFFFFE6A3),fontSize:17,fontWeight:FontWeight.w500,letterSpacing:1.8)):const SizedBox(height:22))));}

class _GlassLabel extends StatelessWidget {
  @override Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.symmetric(horizontal:18, vertical:9),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(.07),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: _DedicationConfig.gold.withOpacity(.28)),
    ),
    child: const Text('إهداء خاص', style: TextStyle(color: Color(0xFFFFE9A6), fontSize:12, letterSpacing:2.4, fontWeight:FontWeight.w600)),
  );
}
class _MemoryCaption extends StatelessWidget {
  const _MemoryCaption();
  @override Widget build(BuildContext c) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(width:34,height:1,color:_DedicationConfig.gold.withOpacity(.35)),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal:12),
        child: Text('من القلب إلى القلب', style: TextStyle(color:Color(0xB3FFFFFF),fontSize:12,letterSpacing:1.5)),
      ),
      Container(width:34,height:1,color:_DedicationConfig.gold.withOpacity(.35)),
    ],
  );
}
class _CloseHint extends StatelessWidget {
  @override Widget build(BuildContext c) => Text(
    'اضغط على زر الإغلاق للعودة',
    textAlign: TextAlign.center,
    style: TextStyle(color:Colors.white.withOpacity(.32),fontSize:11,letterSpacing:.8),
  );
}
class _CloseButton extends StatelessWidget {
  @override Widget build(BuildContext c) => Material(
    color: Colors.white.withOpacity(.07),
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: () => Navigator.of(c).maybePop(),
      child: const SizedBox(width:42,height:42,child:Tooltip(message:'إغلاق',child:Icon(Icons.close_rounded,color:Color(0xD9FFFFFF),size:20))),
    ),
  );
}
class _LetterCard extends StatelessWidget {
  final Widget child;
  const _LetterCard({required this.child});
  @override Widget build(BuildContext c) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(24,28,24,28),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(.065),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: Colors.white.withOpacity(.14)),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(.22),blurRadius:34,offset:const Offset(0,18)),
        BoxShadow(color:_DedicationConfig.pink.withOpacity(.07),blurRadius:28,spreadRadius:2),
      ],
    ),
    child: child,
  );
}
class _MemoHeart extends StatelessWidget{final AnimationController controller;const _MemoHeart({required this.controller});@override Widget build(BuildContext c)=>AnimatedBuilder(animation:controller,builder:(_,__) {final v=controller.value,g=24+v*34;return Transform.scale(scale:1+v*.08,child:CustomPaint(size:const Size(148,148),painter:_MemoHeartPainter(glow:g)));});}
class _MemoHeartPainter extends CustomPainter{final double glow;_MemoHeartPainter({required this.glow});@override void paint(Canvas c,Size s){final center=Offset(s.width/2,s.height/2);final halo=Paint()..color=_DedicationConfig.pink.withOpacity(.18)..maskFilter=MaskFilter.blur(BlurStyle.normal,glow);c.drawCircle(center,42,halo);final path=Path()..moveTo(s.width*.5,s.height*.78)..cubicTo(s.width*.36,s.height*.64,s.width*.12,s.height*.49,s.width*.14,s.height*.29)..cubicTo(s.width*.16,s.height*.10,s.width*.40,s.height*.06,s.width*.5,s.height*.25)..cubicTo(s.width*.60,s.height*.06,s.width*.84,s.height*.10,s.width*.86,s.height*.29)..cubicTo(s.width*.88,s.height*.49,s.width*.64,s.height*.64,s.width*.5,s.height*.78)..close();final fill=Paint()..shader=ui.Gradient.linear(Offset(0,s.height*.1),Offset(s.width,s.height*.85),[_DedicationConfig.pink,_DedicationConfig.gold]);c.drawPath(path,fill);final shine=Paint()..color=Colors.white.withOpacity(.28)..strokeWidth=3..style=PaintingStyle.stroke;c.drawArc(Rect.fromCircle(center:Offset(s.width*.37,s.height*.35),radius:22),3.55,1.1,false,shine);} @override bool shouldRepaint(_MemoHeartPainter old)=>old.glow!=glow;}

class _GoldenDivider extends StatefulWidget{final Duration delay;const _GoldenDivider({required this.delay});@override State<_GoldenDivider> createState()=>_GoldenDividerState();}
class _GoldenDividerState extends State<_GoldenDivider> with SingleTickerProviderStateMixin{late final AnimationController c;@override void initState(){super.initState();c=AnimationController(vsync:this,duration:const Duration(milliseconds:1200));Future.delayed(widget.delay,(){if(mounted)c.forward();});}@override void dispose(){c.dispose();super.dispose();}@override Widget build(BuildContext x)=>AnimatedBuilder(animation:c,builder:(_,__)=>SizedBox(width:220*c.value,height:2,child:const DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(colors:[Colors.transparent,_DedicationConfig.gold,_DedicationConfig.pink,_DedicationConfig.gold,Colors.transparent])))));}
class _PulsingClosing extends StatefulWidget{final String text;final Duration delay;const _PulsingClosing({required this.text,required this.delay});@override State<_PulsingClosing> createState()=>_PulsingClosingState();}
class _PulsingClosingState extends State<_PulsingClosing> with SingleTickerProviderStateMixin{late final AnimationController c;bool v=false;@override void initState(){super.initState();c=AnimationController(vsync:this,duration:const Duration(milliseconds:1400));Future.delayed(widget.delay,(){if(mounted){setState(()=>v=true);c.repeat(reverse:true);}});}@override void dispose(){c.dispose();super.dispose();}@override Widget build(BuildContext x)=>v?AnimatedBuilder(animation:c,builder:(_,__)=>Transform.scale(scale:1+c.value*.08,child:Opacity(opacity:.7+c.value*.3,child:Text(widget.text,style:const TextStyle(fontSize:30,color:_DedicationConfig.pink,fontWeight:FontWeight.bold))))):const SizedBox(height:40);}
class _TypewriterText extends StatefulWidget{final String text;final TextStyle style;final double charsPerSecond;final Duration delay;final TextAlign align;const _TypewriterText({required this.text,required this.style,this.charsPerSecond=20,this.delay=Duration.zero,this.align=TextAlign.center});@override State<_TypewriterText> createState()=>_TypewriterTextState();}
class _TypewriterTextState extends State<_TypewriterText> with SingleTickerProviderStateMixin{String v='';bool done=false;late final AnimationController cursor;@override void initState(){super.initState();cursor=AnimationController(vsync:this,duration:const Duration(milliseconds:600))..repeat(reverse:true);start();}Future<void> start()async{await Future.delayed(widget.delay);if(!mounted)return;final d=Duration(milliseconds:(1000/widget.charsPerSecond).round());for(var i=0;i<=widget.text.length;i++){if(!mounted)return;setState(()=>v=widget.text.substring(0,i));await Future.delayed(d);}if(mounted){cursor.stop();setState(()=>done=true);}}@override void dispose(){cursor.dispose();super.dispose();}@override Widget build(BuildContext c)=>done?Text(widget.text,style:widget.style,textAlign:widget.align):AnimatedBuilder(animation:cursor,builder:(_,__)=>Text(v+(cursor.value>.5?'▌':' '),style:widget.style,textAlign:widget.align));}
class _Star{final double x,y,size,phase,speed,drift;_Star(this.x,this.y,this.size,this.phase,this.speed,this.drift);}
class _Heart{final double x,y,size,speed,amp,phase,hue;_Heart(this.x,this.y,this.size,this.speed,this.amp,this.phase,this.hue);}
class _Petal{final double x,y,size,speed,rot,amp,phase;_Petal(this.x,this.y,this.size,this.speed,this.rot,this.amp,this.phase);}
class _StarsPainter extends CustomPainter{final List<_Star>s;final double t;_StarsPainter(this.s,this.t);@override void paint(Canvas c,Size z){final p=Paint(),g=Paint();for(final a in s){final o=.2+((sin(t*2*pi*a.speed+a.phase)+1)/2)*.8, y=((a.y-t*.08)%1)*z.height,x=((a.x+sin(t*2*pi+a.phase)*a.drift)%1)*z.width;g.color=_DedicationConfig.gold.withOpacity(o*.35);c.drawCircle(Offset(x,y),a.size*3,g);p.color=const Color(0xFFFFF8DC).withOpacity(o);c.drawCircle(Offset(x,y),a.size,p);}}@override bool shouldRepaint(_)=>true;}
class _HeartsPainter extends CustomPainter{final List<_Heart>h;final double t;_HeartsPainter(this.h,this.t);@override void paint(Canvas c,Size z){for(final a in h){final y=((a.y-t*a.speed)%1.6)*z.height,x=(a.x+sin(t*2*pi+a.phase)*a.amp)*z.width,o=(1-(y/z.height-.5).abs()*1.6).clamp(0.0,1.0),col=HSVColor.fromAHSV(1,a.hue%360,.6,1).toColor().withOpacity(o*.7);final p=Path()..moveTo(x,y+a.size*.35)..cubicTo(x-a.size*1.3,y-a.size*.6,x-a.size*.5,y-a.size*1.4,x,y-a.size*.5)..cubicTo(x+a.size*.5,y-a.size*1.4,x+a.size*1.3,y-a.size*.6,x,y+a.size*.35)..close();c.drawPath(p,Paint()..color=col);}}@override bool shouldRepaint(_)=>true;}
class _PetalsPainter extends CustomPainter{final List<_Petal>p;final double t;_PetalsPainter(this.p,this.t);@override void paint(Canvas c,Size z){for(final a in p){final y=((a.y+t*a.speed)%1.4)*z.height,x=(a.x+sin(t*2*pi+a.phase)*a.amp)*z.width;c.save();c.translate(x,y);c.rotate(t*2*pi*a.rot);c.drawOval(Rect.fromCenter(center:Offset.zero,width:a.size,height:a.size*1.6),Paint()..color=_DedicationConfig.gold.withOpacity(.55));c.restore();}}@override bool shouldRepaint(_)=>true;}
class _BeamPainter extends CustomPainter{final double t;_BeamPainter(this.t);@override void paint(Canvas c,Size z){if(t>.4)return;final x=t/.4*z.width*1.4-z.width*.2;c.save();c.translate(x,0);c.rotate(.25);c.drawRect(Rect.fromLTWH(-80,-z.height*.2,160,z.height*1.4),Paint()..shader=const LinearGradient(colors:[Colors.transparent,Color(0x26FFD700),Color(0x66FFFFFF),Color(0x26FFD700),Colors.transparent]).createShader(Rect.fromLTWH(-80,0,160,z.height)));c.restore();}@override bool shouldRepaint(_)=>true;}
class SecretSevenTap extends StatefulWidget{final Widget child;const SecretSevenTap({super.key,required this.child});@override State<SecretSevenTap> createState()=>_SecretSevenTapState();}
class _SecretSevenTapState extends State<SecretSevenTap>{int taps=0;DateTime? last;bool opened=false;Future<void> tap()async{if(opened)return;final n=DateTime.now();if(last!=null&&n.difference(last!).inMilliseconds>1500)taps=0;last=n;taps++;HapticFeedback.selectionClick();if(taps==3)HapticFeedback.lightImpact();if(taps<7)return;opened=true;taps=0;HapticFeedback.heavyImpact();if(!mounted)return;await Navigator.of(context).push(PageRouteBuilder(opaque:true,transitionDuration:const Duration(milliseconds:1000),pageBuilder:(_,__,___)=>const MemoDedicationScreen(),transitionsBuilder:(_,a,__,child)=>FadeTransition(opacity:a,child:ScaleTransition(scale:Tween(begin:.92,end:1.0).animate(a),child:child))));opened=false;}@override Widget build(BuildContext c)=>GestureDetector(onTap:tap,behavior:HitTestBehavior.opaque,child:child);}

class _VignettePainter extends CustomPainter{ @override void paint(Canvas c,Size s){final rect=Offset.zero& s;final p=Paint()..shader=ui.Gradient.radial(Offset(s.width/2,s.height*.42),s.longestSide*.72,[Colors.transparent,Colors.black.withOpacity(.08),Colors.black.withOpacity(.48)],[.42,.72,1]);c.drawRect(rect,p);} @override bool shouldRepaint(_)=>false;}
