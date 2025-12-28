
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:socialbunkr_mobile_app/screens/list_your_room_bed_screen.dart';
import 'package:socialbunkr_mobile_app/screens/availability_management_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socialbunkr_mobile_app/screens/tenant_management/expense_tracker_screen.dart';
import 'package:socialbunkr_mobile_app/screens/tenant_management/occupancy_overview_screen.dart';
import 'package:socialbunkr_mobile_app/screens/tenant_management/rating_review_screen.dart';
import 'package:socialbunkr_mobile_app/screens/tenant_management/rent_payment_screen.dart';
import 'package:socialbunkr_mobile_app/screens/tenant_management/tickets_screen.dart';
import 'package:socialbunkr_mobile_app/screens/update_property_details_screen.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:html' as html;



// 🎨 BRAND COLORS & STYLES
const Color primaryDarkGreen = Color(0xFF0B3D2E);
const Color accentGold = Color(0xFFE9B949);
const Color backgroundWhite = Color(0xFFFFFFFF);
const Color neutralGreenGray = Color(0xFF4C6158);
const Color lightGrayBackground = Color(0xFFF8FAF8);
const Color inactiveTabGray = Color(0xFFEAEDEB);
const Color cardBorderGray = Color(0xFFE8ECE9);
const Color dividerGray = Color(0xFFE0E0E0);
const Color textBlack = Color(0xFF1F1F1F);
const Color textGray = Color(0xFF6C757D);
const BoxShadow cardShadow = BoxShadow(
  color: Color.fromRGBO(0, 0, 0, 0.08),
  blurRadius: 12,
  offset: Offset(0, 4),
);
const BoxShadow softShadow = BoxShadow(
  color: Color(0x0D000000),
  blurRadius: 10,
  offset: Offset(0, 2),
);

// --- FONT STYLES ---
const String fontName = 'Poppins';

// Booking Model
class Booking {
  final String id;
  final String booking_id;
  final String guestName;
  final String guestPhoneNumber;
  final String checkIn;
  final String checkOut;
  final String totalPrice;
  final String status;
  final String payoutStatus;

  Booking({
    required this.id,
    required this.booking_id,
    required this.guestName,
    required this.guestPhoneNumber,
    required this.checkIn,
    required this.checkOut,
    required this.totalPrice,
    required this.status,
    required this.payoutStatus,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'].toString(),
      booking_id: json['booking_id'].toString(),
      guestName: json['guest_name'] ?? 'N/A',
      guestPhoneNumber: json['guest_phone_number'] ?? 'N/A',
      checkIn: json['checkin'] ?? 'N/A',
      checkOut: json['checkout'] ?? 'N/A',
      totalPrice:
          '₹${double.tryParse(json['total_price']?.toString() ?? '')?.toStringAsFixed(0) ?? '0'}',
      status: json['status'] ?? 'N/A',
      payoutStatus: json['payout_status'] ?? 'N/A',
    );
  }
}

class HostDashboardPage extends StatelessWidget {
  final String propertyId;
  const HostDashboardPage({super.key, required this.propertyId});

  @override
  Widget build(BuildContext context) {
    print('HostDashboardPage: Received propertyId: $propertyId'); // Debug print
    return Scaffold(
      backgroundColor: lightGrayBackground,
      appBar: HeaderWidget(
        propertyId: propertyId,
        onUpdatePropertyDetails: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => UpdatePropertyDetailsScreen(propertyId: propertyId)),
          );
        },
      ),
      body: HostDashboardBody(propertyId: propertyId),
    );
  }
}

// 1️⃣ HEADER SECTION
class HeaderWidget extends StatelessWidget implements PreferredSizeWidget {
  final String propertyId;
  final VoidCallback onUpdatePropertyDetails;

  const HeaderWidget({super.key, required this.propertyId, required this.onUpdatePropertyDetails});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundWhite,
      elevation: 0,
      centerTitle: true,
      title: RichText(
        textAlign: TextAlign.center,
        text: const TextSpan(
          style: TextStyle(
            fontFamily: fontName,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: primaryDarkGreen,
          ),
          children: [
            TextSpan(text: 'Social'),
            TextSpan(
              text: 'Bunkr',
              style: TextStyle(
                decoration: TextDecoration.underline,
                decorationColor: accentGold,
                decorationThickness: 2.0,
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, color: primaryDarkGreen),
          onPressed: onUpdatePropertyDetails,
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: accentGold,
            child: Icon(
              Icons.person_outline,
              color: primaryDarkGreen,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class HostDashboardBody extends StatefulWidget {
  final String propertyId;
  const HostDashboardBody({super.key, required this.propertyId});

  @override
  _HostDashboardBodyState createState() => _HostDashboardBodyState();
}

class _HostDashboardBodyState extends State<HostDashboardBody> {
  int _mainTabIndex = 0;
  int _bookingTabIndex = 0;
  List<Booking> _upcomingBookings = [];
  List<Booking> _ongoingBookings = [];
  List<Booking> _completedBookings = [];
  bool _isLoadingBookings = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    setState(() {
      _isLoadingBookings = true;
      _errorMessage = '';
    });

    try {
      final String? apiBaseUrl = kIsWeb ? dotenv.env['API_BASE_URL_WEB']! : dotenv.env['API_BASE_URL_ANDROID']!;
      final String propertyID = widget.propertyId;
      final _secureStorage = FlutterSecureStorage();
      final token = await _secureStorage.read(key: 'token');

      if (apiBaseUrl == null) {
        throw Exception('API_BASE_URL is not defined in .env');
      }

      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/payments/properties/$propertyID/orders/'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Token $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          _upcomingBookings = (data['Upcoming'] as List)
              .map((e) => Booking.fromJson(e))
              .toList();
          _ongoingBookings = (data['Ongoing'] as List)
              .map((e) => Booking.fromJson(e))
              .toList();
          _completedBookings = (data['Completed'] as List)
              .map((e) => Booking.fromJson(e))
              .toList();
        });
      } else {
        _errorMessage =
            'Failed to load bookings: ${response.statusCode} ${response.reasonPhrase}';
      }
    } catch (e) {
      _errorMessage = 'Error fetching bookings: $e';
    } finally {
      setState(() {
        _isLoadingBookings = false;
      });
    }
  }

  void _onMainTabSelected(int index) {
    setState(() {
      _mainTabIndex = index;
    });
  }

  void _updateBookingStatus(String bookingId) {
    setState(() {
      final bookingIndex = _upcomingBookings.indexWhere((b) => b.booking_id == bookingId);
      if (bookingIndex != -1) {
        final booking = _upcomingBookings.removeAt(bookingIndex);
        final updatedBooking = Booking(
          id: booking.id,
          booking_id: booking.booking_id,
          guestName: booking.guestName,
          guestPhoneNumber: booking.guestPhoneNumber,
          checkIn: booking.checkIn,
          checkOut: booking.checkOut,
          totalPrice: booking.totalPrice,
          status: 'Ongoing',
          payoutStatus: booking.payoutStatus,
        );
        _ongoingBookings.add(updatedBooking);
      }
    });
  }

  void _updateBookingStatusForCheckout(String bookingId) {
    setState(() {
      final bookingIndex = _ongoingBookings.indexWhere((b) => b.booking_id == bookingId);
      if (bookingIndex != -1) {
        final booking = _ongoingBookings.removeAt(bookingIndex);
        final updatedBooking = Booking(
          id: booking.id,
          booking_id: booking.booking_id,
          guestName: booking.guestName,
          guestPhoneNumber: booking.guestPhoneNumber,
          checkIn: booking.checkIn,
          checkOut: booking.checkOut,
          totalPrice: booking.totalPrice,
          status: 'Completed',
          payoutStatus: booking.payoutStatus,
        );
        _completedBookings.add(updatedBooking);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        MainTabToggle(
          selectedIndex: _mainTabIndex,
          onTabSelected: _onMainTabSelected,
        ),
        const SizedBox(height: 20),
        if (_mainTabIndex == 0)
          Expanded(
            child: DefaultTabController(
              length: 2, // Two tabs: Booking and List Vacant Beds
              initialIndex: _bookingTabIndex, // Use the existing state for initial selection
              child: Container(
                color: lightGrayBackground, // Explicitly set background color
                child: Column(
                  children: [
                    TabBar(
                      isScrollable: true,
                      labelColor: primaryDarkGreen,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: accentGold,
                      indicatorWeight: 3,
                      onTap: (index) {
                        setState(() {
                          _bookingTabIndex = index; // Update _bookingTabIndex when a tab is tapped
                        });
                      },
                      tabs: const [
                        Tab(icon: Icon(Icons.book_outlined), text: "Booking"),
                        Tab(icon: Icon(Icons.bed_outlined), text: "List Vacant Beds"),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _isLoadingBookings
                              ? const Center(child: CircularProgressIndicator())
                              : _errorMessage.isNotEmpty
                                  ? Center(
                                      child: Text(
                                        _errorMessage,
                                        style: const TextStyle(color: Colors.red),
                                      ),
                                    )
                                  : BookingTabView(
                                      upcomingBookings: _upcomingBookings,
                                      ongoingBookings: _ongoingBookings,
                                      completedBookings: _completedBookings,
                                      onCheckInSuccess: _updateBookingStatus,
                                      onCheckOutSuccess: _updateBookingStatusForCheckout,
                                    ),
                          ListVacantBedsContent(propertyId: widget.propertyId),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Expanded(
            child: TenantManagementView(propertyId: widget.propertyId),
          ),
      ],
    );
  }
}

class TenantManagementView extends StatelessWidget {
  final String propertyId;
  const TenantManagementView({super.key, required this.propertyId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(

        appBar: AppBar(
          backgroundColor: backgroundWhite,
          elevation: 1,
          toolbarHeight: 0,
          bottom: const TabBar(
            isScrollable: true,
            labelColor: primaryDarkGreen,
            unselectedLabelColor: Colors.grey,
            indicatorColor: accentGold,
            indicatorWeight: 3,
            tabs: [
              Tab(icon: Icon(Icons.pie_chart_outline), text: "Occupancy"),
              Tab(icon: Icon(Icons.payment_outlined), text: "Rent"),
              Tab(icon: Icon(Icons.receipt_long_outlined), text: "Expenses"),
              Tab(icon: Icon(Icons.support_agent_outlined), text: "Tickets"),
              Tab(icon: Icon(Icons.star_outline), text: "Reviews"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            OccupancyOverviewScreen(propertyId: propertyId),
            RentPaymentScreen(propertyId: propertyId),
            ExpenseTrackerScreen(propertyId: propertyId),
            TicketsScreen(propertyId: propertyId),
            RatingReviewScreen(propertyId: propertyId),
          ],
        ),
      ),
    );
  }
}


// 2️⃣ TOP TOGGLE (MAIN TABS)
class MainTabToggle extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const MainTabToggle(
      {super.key, required this.selectedIndex, required this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: inactiveTabGray,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _buildTab(context, "List & Earn Extra", 0),
          _buildTab(context, "Tenant Management", 1),
        ],
      ),
    );
  }

  Widget _buildTab(BuildContext context, String text, int index) {
    final bool isActive = selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTabSelected(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? primaryDarkGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: fontName,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: isActive ? Colors.white : primaryDarkGreen,
            ),
          ),
        ),
      ),
    );
  }
}



// 4️⃣ BOOKING TAB CONTENT
class BookingTabView extends StatelessWidget {
  final List<Booking> upcomingBookings;
  final List<Booking> ongoingBookings;
  final List<Booking> completedBookings;
  final Function(String) onCheckInSuccess;
  final Function(String) onCheckOutSuccess;

  const BookingTabView({
    super.key,
    required this.upcomingBookings,
    required this.ongoingBookings,
    required this.completedBookings,
    required this.onCheckInSuccess,
    required this.onCheckOutSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Upcoming'),
              Tab(text: 'Ongoing'),
              Tab(text: 'Completed'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                BookingList(bookings: upcomingBookings, onCheckInSuccess: onCheckInSuccess, onCheckOutSuccess: onCheckOutSuccess),
                BookingList(bookings: ongoingBookings, onCheckInSuccess: onCheckInSuccess, onCheckOutSuccess: onCheckOutSuccess),
                BookingList(bookings: completedBookings, onCheckInSuccess: onCheckInSuccess, onCheckOutSuccess: onCheckOutSuccess),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BookingList extends StatelessWidget {
  final List<Booking> bookings;
  final Function(String) onCheckInSuccess;
  final Function(String) onCheckOutSuccess;

  const BookingList({
    super.key,
    required this.bookings,
    required this.onCheckInSuccess,
    required this.onCheckOutSuccess,
  });

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return const Center(
        child: Text(
          'No bookings found.',
          style: TextStyle(fontFamily: fontName, fontSize: 16, color: neutralGreenGray),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        // This is not ideal, but it will work for now.
        // A better solution would be to use a state management library.
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          final booking = bookings[index];
          return BookingCard(
            booking: booking,
            onCheckIn: () => _showCheckInDialog(context, booking, onCheckInSuccess),
            onCheckOutSuccess: onCheckOutSuccess,
            onCardClick: () => _showBookingDetailsDialog(context, booking),
          );
        },
      ),
    );
  }
}

class BookingCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback onCheckIn;
  final Function(String) onCheckOutSuccess;
  final VoidCallback onCardClick;

  const BookingCard({
    super.key,
    required this.booking,
    required this.onCheckIn,
    required this.onCheckOutSuccess,
    required this.onCardClick,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCardClick,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundWhite,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [cardShadow],
        ),
        child: Row(
          children: [
            const Icon(Icons.bed_outlined, color: primaryDarkGreen, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.guestName,
                    style: const TextStyle(
                      fontFamily: fontName,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: primaryDarkGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildDateColumn("Check-in", booking.checkIn),
                      Container(
                        height: 30,
                        width: 1,
                        color: dividerGray,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      _buildDateColumn("Check-out", booking.checkOut),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (booking.status.toLowerCase() == 'upcoming')
              ElevatedButton(
                onPressed: onCheckIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentGold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: const Text(
                  "CHECK-IN",
                  style: TextStyle(
                    fontFamily: fontName,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              )
            else if (booking.status.toLowerCase() == 'ongoing')
              ElevatedButton(
                onPressed: () => _showCheckOutDialog(context, booking, onCheckOutSuccess),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: const Text(
                  "CHECK-OUT",
                  style: TextStyle(
                    fontFamily: fontName,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateColumn(String label, String date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: fontName,
            fontSize: 12,
            color: textGray,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          date,
          style: const TextStyle(
            fontFamily: fontName,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textBlack,
          ),
        ),
      ],
    );
  }
}

void _showBookingDetailsDialog(BuildContext context, Booking booking) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Booking Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Guest Name: ${booking.guestName}'),
              Text('Guest Phone: ${booking.guestPhoneNumber}'),
              Text('Check-in: ${booking.checkIn}'),
              Text('Check-out: ${booking.checkOut}'),
              Text('Total Price: ${booking.totalPrice}'),
              Text('Status: ${booking.status}'),
              if (booking.status.toLowerCase() == 'completed') ...[
                Text('Payout Status: ${booking.payoutStatus}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _downloadInvoice(context, booking.booking_id),
                  child: const Text('Download Invoice'),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

void _downloadInvoice(BuildContext context, String bookingId) async {
  try {
    final String? apiBaseUrl = kIsWeb ? dotenv.env['API_BASE_URL_WEB']! : dotenv.env['API_BASE_URL_ANDROID']!;
    final _secureStorage = FlutterSecureStorage();
    final token = await _secureStorage.read(key: 'token');

    if (apiBaseUrl == null) {
      throw Exception('API_BASE_URL is not defined in .env');
    }

    final response = await http.get(
      Uri.parse('$apiBaseUrl/api/payments/orders/$bookingId/invoice/'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Token $token',
      },
    );

    if (response.statusCode == 200) {
      if (kIsWeb) {
        final blob = html.Blob([response.bodyBytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute("download", "invoice-$bookingId.html")
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/invoice-$bookingId.html';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        OpenFile.open(filePath);
      }
    } else {
      final error = json.decode(response.body)['error'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download invoice: $error')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('An error occurred: $e')),
    );
  }
}

void _showCheckInDialog(BuildContext context, Booking booking, Function(String) onCheckInSuccess) {
  final otpController = TextEditingController();
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Enter OTP'),
        content: TextField(
          controller: otpController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'OTP',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final otp = otpController.text;
              if (otp.isNotEmpty) {
                Navigator.pop(context);
                _performCheckIn(context, booking.booking_id, otp, onCheckInSuccess);
              }
            },
            child: const Text('Check-in'),
          ),
        ],
      );
    },
  );
}

void _performCheckIn(BuildContext context, String bookingId, String otp, Function(String) onCheckInSuccess) async {
  try {
    final String? apiBaseUrl = kIsWeb ? dotenv.env['API_BASE_URL_WEB']! : dotenv.env['API_BASE_URL_ANDROID']!;
    final _secureStorage = FlutterSecureStorage();
    final token = await _secureStorage.read(key: 'token');

    if (apiBaseUrl == null) {
      throw Exception('API_BASE_URL is not defined in .env');
    }

    final response = await http.post(
      Uri.parse('$apiBaseUrl/api/guests/guest-check/check-in/'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Token $token',
      },
      body: json.encode({
        'order_id': bookingId,
        'otp': otp,
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-in successful!')),
      );
      onCheckInSuccess(bookingId);
    } else {
      final error = json.decode(response.body)['error'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Check-in failed: $error')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('An error occurred: $e')),
    );
  }
}

void _showCheckOutDialog(BuildContext context, Booking booking, Function(String) onCheckOutSuccess) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Confirm Check-out'),
        content: const Text('Are you sure you want to check-out this guest?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              _performCheckOut(context, booking.booking_id, onCheckOutSuccess);
            },
            child: const Text('Check-out'),
          ),
        ],
      );
    },
  );
}

void _performCheckOut(BuildContext context, String bookingId, Function(String) onCheckOutSuccess) async {
  try {
    final String? apiBaseUrl = kIsWeb ? dotenv.env['API_BASE_URL_WEB']! : dotenv.env['API_BASE_URL_ANDROID']!;
    final _secureStorage = FlutterSecureStorage();
    final token = await _secureStorage.read(key: 'token');

    if (apiBaseUrl == null) {
      throw Exception('API_BASE_URL is not defined in .env');
    }

    final response = await http.post(
      Uri.parse('$apiBaseUrl/api/guests/bookings/$bookingId/checkout/'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Token $token',
      },
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-out successful!')),
      );
      onCheckOutSuccess(bookingId);
    } else {
      final error = json.decode(response.body)['error'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Check-out failed: $error')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('An error occurred: $e')),
    );
  }
}


// 5️⃣ LIST VACANT BEDS TAB CONTENT
class ListVacantBedsContent extends StatelessWidget {
  final String propertyId;
  ListVacantBedsContent({super.key, required this.propertyId});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 1,
      childAspectRatio: 3.5,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      mainAxisSpacing: 12,
      children: [
        PropertyActionCard(
          icon: Icons.add_business_outlined,
          title: "List Your Room/Bed",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ListYourRoomBedScreen(propertyId: propertyId)),
            );
          },
        ),
        PropertyActionCard(
          icon: Icons.calendar_today_outlined,
          title: "Update Bed/Room Availability",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AvailabilityManagementScreen(propertyId: propertyId)),
            );
          },
        ),
        
      ],
    );
  }
}

class PropertyActionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap; // Added onTap callback

  const PropertyActionCard({
    super.key,
    required this.icon,
    required this.title,
    this.onTap, // Added onTap to constructor
  });

  @override
  _PropertyActionCardState createState() => _PropertyActionCardState();
}

class _PropertyActionCardState extends State<PropertyActionCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => _scale = 0.97); // Animate on tap
        Future.delayed(const Duration(milliseconds: 150), () {
          setState(() => _scale = 1.0); // Reset scale after animation
          widget.onTap?.call(); // Trigger the actual navigation
        });
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: backgroundWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cardBorderGray, width: 1),
            boxShadow: const [softShadow],
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: primaryDarkGreen, size: 28),
              const SizedBox(width: 16),
              Text(
                widget.title,
                style: const TextStyle(
                  fontFamily: fontName,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: primaryDarkGreen,
                ),
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios,
                  color: neutralGreenGray, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
