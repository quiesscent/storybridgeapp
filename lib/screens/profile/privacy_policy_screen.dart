import 'package:flutter/material.dart';
import 'package:story_app/theme/google_fonts.dart';
import '../../theme/tokens.dart';
import '../../widgets/profile_top_bar.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;

    return Scaffold(
      backgroundColor: tokens.cream,
      appBar: ProfileTopBar(
        subtitle: 'Privacy Policy',
        onBackTap: () => Navigator.pop(context),
        tokens: tokens,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Last Updated: 21 April 2026', style: GoogleFonts.nunito(fontSize: 12, color: tokens.darkSlate)),
            const SizedBox(height: 24),
            _buildSection(tokens, '1. Introduction', 'Welcome to StoryBridge Limited\'s Privacy and Data Protection Policy ("Privacy Policy").\n\nAt StoryBridge Limited ("we", "us", or "our") we are committed to protecting and respecting your privacy and Personal Data in compliance with the United Kingdom General Data Protection Regulation ("GDPR"), the Data Protection Act 2018 and all other mandatory laws and regulations of the United Kingdom.\n\nThis Privacy Policy explains how we collect, process and keep your data safe. The Privacy Policy will tell you about your privacy rights, how the law protects you, and inform our employees and staff members of all their obligations and protocols when processing data.\n\nThe individuals from which we may gather and use data can include: Customers, and any other people that the organisation has a relationship with or may need to contact.\n\nThis Privacy Policy applies to all our employees and staff members and all Personal Data processed at any time by us.\n\nStoryBridge Limited is your Data Controller and responsible for your Personal Data. We are not obliged by the GDPR to appoint a data protection officer and have not voluntarily appointed one at this time. Therefore, any inquiries about your data should either be sent to us by email to support@storybridgeapp.co.uk or by post to 5 South View, Monkton Combe, Bath, BA2 7EY, United Kingdom.\n\nYou have the right to make a complaint at any time to the Information Commissioner\'s Office (ICO), the UK supervisory authority for data protection issues (www.ico.org.uk). We would, however, appreciate the chance to deal with your concerns before you approach the ICO so please contact us in the first instance.'),
            _buildSection(tokens, '2. Legal Basis for Data Collection', '"Personal Data" means any information about an individual from which that person can be identified. It does not include data where the identity has been removed (anonymous data).\n\nWe may collect, use, store and transfer different kinds of Personal Data about you:\n\n• Profile/Identity Data: your first name, last name, gender, date of birth.\n• Contact Data: your phone number, addresses, email addresses.\n• Marketing and Communications Data: your preferences in receiving marketing information from us.\n• Technical Data: your IP address, browser type and version, time zone setting and location, operating system and platform, and other technology on the devices you use to engage with us.\n• Usage Data: information about how you use our website, products and services.\n\nWe also collect, use and share Aggregated Data such as how many stories have been shared over the course of a time period. Aggregated Data is not considered Personal Data in law as it will not directly or indirectly reveal your identity.\n\nWe do not collect any Special Categories of Personal Data about you (this includes details about your race or ethnicity, religious or philosophical beliefs, sex life, sexual orientation, political opinions, trade union membership, information about your health, and genetic and biometric data). Nor do we collect any information about criminal convictions and offences.\n\nThe main legal bases we rely on for collecting data are: Consent, Contractual Obligations, Legal Compliance, and Legitimate Interest.'),
            _buildSection(tokens, '3. How We Use Your Personal Data', 'We will only use your Personal Data when the law allows us to.\n\nWhen a customer signs up for a waitlist or newsletter, we process Profile/Identity Data, Contact Data, and Marketing and Communications Data based on Consent — to keep our customers up to date about our products, events and services.\n\nWhen a customer visits our website, we process Usage Data based on Consent — to better customise our product to our customers.\n\nWhen a customer creates an account on our app, we process Profile/Identity Data, Billing Data, Technical Data, Customer Support Data, and Usage Data based on Consent and Explicit Consent — to provide adequate services to customers that have purchased from us.\n\nYou will receive marketing and new content communications from us if you have created an account and chosen to opt into receiving those communications.\n\nWe will only use your Personal Data for the purposes for which we collected it, unless we reasonably consider that we need to use it for another reason compatible with the original purpose. If we need to use your Personal Data for an unrelated purpose, we will notify you and explain the legal basis which allows us to do so.'),
            _buildSection(tokens, '4. Your Rights and How You Are Protected', 'Under certain circumstances, you have the following rights under data protection laws:\n\n• Right to be informed: You have a right to be informed about our purposes for processing your personal data, how long we store it for, and who it will be shared with.\n\n• Right of access: This enables you to receive a copy of the personal data we hold about you and to check that we are lawfully processing it.\n\n• Right to rectification: You have a right to request correction of the personal data that we hold about you.\n\n• Right to erasure: You have the right to ask us to delete or remove personal data where there is no good reason for us continuing to process it.\n\n• Right to object: You can object to the processing of personal data we hold about you, for example where we are processing it for direct marketing purposes.\n\n• Right to restrict processing: You have the right to request the restriction or suppression of your personal data in certain circumstances.\n\n• Right to data portability: You have the right to request the transfer of your personal data to you or to a third party in a structured, commonly used, machine-readable format.\n\nIf you wish to make a request under any of these rights, please contact us at support@storybridgeapp.co.uk.\n\nYou may delete your account at any time — this will remove your account page from our systems and our related software. We guarantee this will delete all stored data.\n\nYou can ask us to stop sending you marketing messages at any time by unsubscribing to our marketing communications.'),
            _buildSection(tokens, '5. Your Data and Third Parties', 'We may share Personal Data with interested parties in the event that StoryBridge Limited anticipates a change in control or the acquisition of all or part of our business or assets.\n\nIf StoryBridge Limited is sold or makes a sale or transfer, we may, in our sole discretion, transfer, sell or assign your Personal Data to a third party as part of or in connection with that transaction. Upon such transfer, the Privacy Policy of the acquiring entity may govern the further use of your Personal Data.\n\nWe may share your Personal Data at any time if required for legal reasons or in order to enforce our terms or this Privacy Policy.'),
            _buildSection(tokens, '6. How Long We Retain Your Data', 'We will only retain your Personal Data for as long as reasonably necessary to fulfil the purposes we collected it for. We may retain your Personal Data for a longer period than usual in the event of a complaint or if we reasonably believe there is a prospect of litigation in respect to our relationship with you.'),
            _buildSection(tokens, '7. Age Limit for Our Users', 'You must not use StoryBridge Limited unless you are aged 16 or older. If you are under 16 and you access StoryBridge Limited by lying about your age, you must immediately stop using StoryBridge Limited.\n\nThis website is not intended for children and we do not knowingly collect data relating to children.'),
            _buildSection(tokens, '8. International Transfer of Data', 'Your information may be stored and processed in the US or other countries or jurisdictions outside the US where StoryBridge Limited has facilities. By using StoryBridge Limited, you are permitting and consenting to the transfer of information, including Personal Data, outside of the US.'),
            _buildSection(tokens, '9. Notification of Changes and Acceptance of Policy', 'We keep our Privacy Policy under review and will place any updates here. This version is dated 21 April 2026.\n\nBy using StoryBridge Limited, you consent to the collection and use of data by us as set out in this Privacy Policy. Continued access or use of StoryBridge Limited will constitute your express acceptance of any modifications to this Privacy Policy.'),
            _buildSection(tokens, '10. Contact Us', 'For any inquiries about your data, please contact us:\n\nStoryBridge Limited\n5 South View\nMonkton Combe\nBath, BA2 7EY\nUnited Kingdom\n\nEmail: support@storybridgeapp.co.uk'),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(StorybridgeTokens tokens, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 20, color: tokens.coffeeBean)),
          const SizedBox(height: 12),
          Text(content, style: GoogleFonts.nunito(fontSize: 16, color: tokens.darkSlate, height: 1.6)),
        ],
      ),
    );
  }
}
