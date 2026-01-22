import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LegalDisclaimerScreen extends StatelessWidget {
  const LegalDisclaimerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Legal Disclaimer',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1a1a2e),
                  Color(0xFF16213e),
                  Color(0xFF0f0f23),
                ],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection(
                    'LEGAL DISCLAIMER',
                    '''
This Legal Disclaimer ("Disclaimer") governs your access to and use of Agnonymous (the "Platform," "Service," "we," "us," or "our"), including all content, functionality, and services offered on or through the application.

BY ACCESSING OR USING THIS PLATFORM, YOU ACKNOWLEDGE THAT YOU HAVE READ, UNDERSTOOD, AND AGREE TO BE BOUND BY THIS DISCLAIMER. IF YOU DO NOT AGREE TO THESE TERMS, YOU MUST DISCONTINUE USE IMMEDIATELY.
''',
                  ),
                  _buildSection(
                    '1. NO PROFESSIONAL ADVICE',
                    '''
The information, data, prices, and content provided on this Platform, including but not limited to agricultural commodity prices, fertilizer costs, seed pricing, chemical inputs, and equipment valuations (collectively, "Agricultural Data"), are provided for general informational purposes only.

NOTHING CONTAINED HEREIN SHALL BE CONSTRUED AS:
• Professional agricultural advice
• Financial, investment, or trading advice
• Legal, tax, or accounting advice
• A recommendation to buy, sell, or hold any commodity
• A guarantee of price accuracy or market conditions

You should consult with qualified professionals, including licensed agricultural consultants, financial advisors, and legal counsel, before making any business, investment, or operational decisions based on information obtained through this Platform.
''',
                  ),
                  _buildSection(
                    '2. DISCLAIMER OF WARRANTIES',
                    '''
THE PLATFORM AND ALL CONTENT, DATA, AND SERVICES ARE PROVIDED ON AN "AS IS" AND "AS AVAILABLE" BASIS WITHOUT WARRANTIES OF ANY KIND, WHETHER EXPRESS, IMPLIED, STATUTORY, OR OTHERWISE.

TO THE FULLEST EXTENT PERMITTED BY APPLICABLE LAW, WE EXPRESSLY DISCLAIM ALL WARRANTIES, INCLUDING BUT NOT LIMITED TO:

(a) IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, TITLE, AND NON-INFRINGEMENT;

(b) WARRANTIES REGARDING THE ACCURACY, RELIABILITY, COMPLETENESS, TIMELINESS, OR CURRENCY OF ANY AGRICULTURAL DATA, PRICING INFORMATION, OR USER-SUBMITTED CONTENT;

(c) WARRANTIES THAT THE PLATFORM WILL BE UNINTERRUPTED, ERROR-FREE, SECURE, OR FREE OF VIRUSES OR OTHER HARMFUL COMPONENTS;

(d) WARRANTIES ARISING FROM COURSE OF DEALING, COURSE OF PERFORMANCE, OR USAGE OF TRADE.
''',
                  ),
                  _buildSection(
                    '3. USER-GENERATED CONTENT',
                    '''
This Platform enables users to submit, post, and share content anonymously, including price reports, market observations, and agricultural commentary ("User Content").

WE DO NOT VERIFY, ENDORSE, VALIDATE, OR GUARANTEE:
• The accuracy, authenticity, or reliability of any User Content
• The identity, credentials, or qualifications of any user
• The truthfulness of any price reports or market information submitted by users
• The legality or appropriateness of any User Content

USER CONTENT REPRESENTS THE VIEWS AND OPINIONS OF INDIVIDUAL USERS AND DOES NOT NECESSARILY REFLECT THE VIEWS OF THE PLATFORM, ITS OPERATORS, AFFILIATES, OR PARTNERS.

YOU ACKNOWLEDGE THAT RELIANCE ON USER CONTENT IS AT YOUR OWN RISK. We strongly recommend independently verifying all information through official market sources, licensed brokers, or qualified professionals before acting upon any User Content.
''',
                  ),
                  _buildSection(
                    '4. LIMITATION OF LIABILITY',
                    '''
TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, IN NO EVENT SHALL THE PLATFORM, ITS OWNERS, OPERATORS, DIRECTORS, OFFICERS, EMPLOYEES, AGENTS, AFFILIATES, LICENSORS, OR SERVICE PROVIDERS BE LIABLE FOR:

(a) ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, PUNITIVE, OR EXEMPLARY DAMAGES;

(b) DAMAGES FOR LOSS OF PROFITS, REVENUE, GOODWILL, DATA, OR OTHER INTANGIBLE LOSSES;

(c) DAMAGES RESULTING FROM YOUR ACCESS TO, USE OF, OR INABILITY TO USE THE PLATFORM;

(d) DAMAGES RESULTING FROM ANY ERRORS, OMISSIONS, OR INACCURACIES IN AGRICULTURAL DATA OR USER CONTENT;

(e) DAMAGES ARISING FROM UNAUTHORIZED ACCESS TO OR ALTERATION OF YOUR TRANSMISSIONS OR DATA;

(f) DAMAGES ARISING FROM THE CONDUCT OF ANY THIRD PARTY ON THE PLATFORM;

(g) ANY LOSSES INCURRED AS A RESULT OF BUSINESS DECISIONS MADE IN RELIANCE ON PLATFORM CONTENT,

WHETHER BASED ON WARRANTY, CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY, OR ANY OTHER LEGAL THEORY, EVEN IF WE HAVE BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.

IF, NOTWITHSTANDING THE FOREGOING, WE ARE FOUND LIABLE FOR ANY LOSS OR DAMAGE, OUR AGGREGATE LIABILITY SHALL NOT EXCEED ONE HUNDRED DOLLARS (\$100.00 USD).
''',
                  ),
                  _buildSection(
                    '5. INDEMNIFICATION',
                    '''
You agree to defend, indemnify, and hold harmless the Platform, its operators, owners, affiliates, officers, directors, employees, agents, licensors, and service providers from and against any claims, liabilities, damages, judgments, awards, losses, costs, expenses, or fees (including reasonable attorneys' fees) arising out of or relating to:

(a) Your violation of this Disclaimer or any applicable terms of service;
(b) Your use of the Platform and any content you access thereon;
(c) Any User Content you submit, post, or transmit through the Platform;
(d) Your violation of any third-party rights, including intellectual property rights;
(e) Any business decisions made in reliance on Platform content.
''',
                  ),
                  _buildSection(
                    '6. MARKET DATA AND PRICING INFORMATION',
                    '''
Agricultural commodity markets are inherently volatile and subject to rapid price fluctuations. Any pricing data displayed on this Platform:

• May be delayed, stale, or outdated
• May not reflect current or actual market conditions
• May contain errors, inaccuracies, or typographical mistakes
• Should not be used as the sole basis for trading, purchasing, or selling commodities

WE ARE NOT A REGISTERED COMMODITY TRADING ADVISOR, BROKER, OR DEALER. We do not execute trades or transactions on behalf of users. The Platform does not provide access to actual commodity markets.

Users should obtain real-time market data from licensed exchanges, registered brokers, or official market sources before engaging in any commodity transactions.
''',
                  ),
                  _buildSection(
                    '7. THIRD-PARTY LINKS AND CONTENT',
                    '''
The Platform may contain links to third-party websites, applications, or services that are not owned or controlled by us. We have no control over, and assume no responsibility for, the content, privacy policies, or practices of any third-party sites or services.

You acknowledge and agree that we shall not be responsible or liable, directly or indirectly, for any damage or loss caused or alleged to be caused by or in connection with the use of or reliance on any such content, goods, or services available on or through any such websites or services.
''',
                  ),
                  _buildSection(
                    '8. GEOGRAPHIC AND JURISDICTIONAL CONSIDERATIONS',
                    '''
This Platform is operated from jurisdictions that may differ from your location. Agricultural regulations, commodity standards, and market practices vary significantly across provinces, states, and countries.

We make no representation that the Platform, its content, or Agricultural Data is appropriate, accurate, or available for use in any particular jurisdiction. Users are solely responsible for compliance with local laws and regulations applicable to their agricultural operations and commodity transactions.
''',
                  ),
                  _buildSection(
                    '9. MODIFICATIONS TO DISCLAIMER',
                    '''
We reserve the right to modify, amend, or update this Disclaimer at any time, in our sole discretion, without prior notice. Any changes shall become effective immediately upon posting to the Platform.

Your continued use of the Platform following the posting of revised terms constitutes your acceptance of such changes. You are responsible for periodically reviewing this Disclaimer to stay informed of updates.
''',
                  ),
                  _buildSection(
                    '10. SEVERABILITY',
                    '''
If any provision of this Disclaimer is held to be unenforceable or invalid under applicable law, such provision shall be modified to the minimum extent necessary to make it enforceable, or if modification is not possible, shall be severed, and the remaining provisions shall continue in full force and effect.
''',
                  ),
                  _buildSection(
                    '11. GOVERNING LAW',
                    '''
This Disclaimer shall be governed by and construed in accordance with the laws of the applicable jurisdiction, without regard to its conflict of law provisions. Any legal action or proceeding arising under this Disclaimer shall be brought exclusively in the courts of competent jurisdiction, and you hereby consent to personal jurisdiction and venue therein.
''',
                  ),
                  _buildSection(
                    '12. CONTACT INFORMATION',
                    '''
For questions regarding this Legal Disclaimer, please contact:

Agnonymous Support
Email: legal@agnonymous.news

This Legal Disclaimer was last updated on January 22, 2026.
''',
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: Text(
                      '© 2026 Agnonymous. All Rights Reserved.',
                      style: GoogleFonts.inter(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF84CC16),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content.trim(),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[300],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
