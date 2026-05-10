import 'package:flutter/material.dart';
import '../config/app_config.dart';

class SignalBadge extends StatelessWidget {
  final String? signal;
  final double fontSize;
  final EdgeInsets padding;
  const SignalBadge(this.signal,{super.key,this.fontSize=11,this.padding=const EdgeInsets.symmetric(horizontal:10,vertical:4)});
  @override
  Widget build(BuildContext context) {
    final label = signal ?? 'N/A';
    final color = AppConfig.signalColor(signal);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color:  color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.6)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,style: TextStyle(color:color,fontSize:fontSize,fontWeight:FontWeight.w700,letterSpacing:0.8)),
    );
  }
}

// ── IndicatorRow — mobile-safe ────────────────────────────────────────────────
class IndicatorRow extends StatelessWidget {
  final String  label;
  final String? signal;
  final String  value;
  final String? subvalue;
  const IndicatorRow({super.key,required this.label,required this.signal,required this.value,this.subvalue});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 480;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: narrow
          // ── mobile: two-line layout ─────────────────────────────────────
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Flexible(child: Text(label,style:const TextStyle(color:AppConfig.textSecondary,fontSize:12))),
                SignalBadge(signal),
              ]),
              const SizedBox(height: 3),
              Text(value,style:const TextStyle(color:AppConfig.textPrimary,fontSize:12)),
              if (subvalue != null)
                Text(subvalue!,style:const TextStyle(color:AppConfig.textSecondary,fontSize:11)),
            ])
          // ── desktop: single-line layout ─────────────────────────────────
          : Row(children: [
              SizedBox(
                width: 160,
                child: Text(label,style:const TextStyle(color:AppConfig.textSecondary,fontSize:13)),
              ),
              Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(value,style:const TextStyle(color:AppConfig.textPrimary,fontSize:13)),
                if (subvalue!=null) Text(subvalue!,style:const TextStyle(color:AppConfig.textSecondary,fontSize:11)),
              ])),
              SignalBadge(signal),
            ]),
    );
  }
}
