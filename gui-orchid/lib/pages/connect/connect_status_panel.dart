import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:orchid/api/orchid_api_mock.dart';
import 'package:orchid/common/formatting.dart';
import 'package:orchid/orchid/orchid_colors.dart';
import 'package:orchid/orchid/orchid_panel.dart';
import 'package:orchid/orchid/orchid_text.dart';
import 'package:orchid/util/units.dart';

import '../app_routes.dart';

class ConnectStatusPanel extends StatelessWidget {
  final USD bandwidthPrice;
  final double bandwidthAvailableGB;
  final int circuitHops;
  final bool minHeight;

  const ConnectStatusPanel({
    Key key,
    @required this.bandwidthPrice,
    @required this.bandwidthAvailableGB,
    @required this.circuitHops,
    this.minHeight = false,
  }) : super(key: key);

  Widget build(BuildContext context) {
    return FittedBox(
      child: SizedBox(
        width: 312,
        child: Row(
          children: [
            _buildGBPanel(context),
            padx(24),
            _buildUSDPanel(context),
            padx(24),
            _buildHopsPanel(context),
          ],
        ),
      ),
    );
  }

  Widget _buildGBPanel(BuildContext context) {
    var s = S.of(context);
    // await Navigator.pushNamed(context, AppRoutes.identity);
    return _buildPanel(
        icon: SvgPicture.asset('assets/svg/gauge_icon.svg',
            width: 40, height: 35, color: Colors.white),
        text: bandwidthAvailableGB != null
            ? bandwidthAvailableGB.toStringAsFixed(1)
            : '...',
        subtext: s.gb);
  }

  Widget _buildUSDPanel(BuildContext context) {
    var s = S.of(context);
    var price = (bandwidthPrice != null && !MockOrchidAPI.hidePrices)
        ? '\$' + formatCurrency(bandwidthPrice.value)
        : '...';
    return _buildPanel(
        icon: SvgPicture.asset('assets/svg/dollars_icon.svg',
            width: 40, height: 40, color: Colors.white),
        text: price,
        subtext: s.usdgb);
  }

  Widget _buildHopsPanel(BuildContext context) {
    var s = S.of(context);
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, AppRoutes.circuit);
      },
      child: _buildPanel(
          icon: SvgPicture.asset('assets/svg/hops_icon.svg',
              width: 40, height: 25, color: Colors.white),
          text: circuitHops == null ? '' : "$circuitHops" + ' ' + s.hop,
          // No pluralization
          subtext: s.circuit),
    );
  }

  Widget _buildPanel({Widget icon, String text, String subtext}) {
    return SizedBox(
      width: 88,
      height: minHeight ? 74 : 40.0 + 12.0 + 74.0,
      child: OrchidPanel(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!minHeight)
            Container(width: 40, height: 40, child: Center(child: icon)),
          if (minHeight) pady(8) else pady(12),
          Text(text, style: OrchidText.body2),
          pady(4),
          Text(subtext,
              style: OrchidText.caption
                  .copyWith(color: OrchidColors.purpleCaption)),
        ],
      )),
    );
  }
}
