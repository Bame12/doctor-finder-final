import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Doctor Booking App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
      ),
      home: const DoctorListScreen(),
    );
  }
}

class DoctorListScreen extends StatelessWidget {
  const DoctorListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Handle back button action
          },
        ),
        title: Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: const TextField(
            decoration: InputDecoration(
              hintText: 'Search',
              prefixIcon: Icon(Icons.search),
              border: InputBorder.none,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.star_border),
            onPressed: () {
              // Handle star button action
            },
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: Colors.grey,
              child: Text(
                'M',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Doctor Booking',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () {
                // Handle home navigation
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite_border),
              title: const Text('Favourites'),
              onTap: () {
                // Handle favourites navigation
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('My Account'),
              onTap: () {
                // Handle my account navigation
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const <Widget>[
            _TopCard(),
            SizedBox(height: 16.0),
            DoctorCard(
              name: 'Dr Paul Anderson',
              specialty: 'Dermatologist',
              ratingAndDistance: '\$\$\$ • 1.2 km away',
              description: 'Supporting line text lorem ipsum dolor sit amet, consectetur.',
            ),
            SizedBox(height: 8.0),
            DoctorCard(
              name: 'Dr James Peter',
              specialty: 'Cardiologist',
              ratingAndDistance: '\$\$\$ • 1.2 km away',
              description: 'Supporting line text lorem ipsum dolor sit amet, consectetur.',
            ),
            SizedBox(height: 8.0),
            DoctorCard(
              name: 'Dr Junior Reynolds',
              specialty: 'General Practitioner',
              ratingAndDistance: '\$\$\$ • 1.2 km away',
              description: 'Supporting line text lorem ipsum dolor sit amet, consectetur.',
            ),
            // Add more DoctorCard widgets here for other doctors
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            label: 'Favourites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Account',
          ),
        ],
        currentIndex: 0, // Set the initial index if needed
        // selectedItemColor: Colors.blue,
        // unselectedItemColor: Colors.grey,
        // onTap: (int index) {
        //   // Handle bottom navigation item taps
        // },
      ),
    );
  }
}

class _TopCard extends StatelessWidget {
  const _TopCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12.0),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Middle-Star ~ Dr Penny',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Subtitle',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              // Placeholder for the abstract shapes
              SizedBox(
                width: 80.0,
                height: 60.0,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        width: 30.0,
                        height: 20.0,
                        color: Colors.grey[400], // Placeholder color
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 20.0,
                        height: 20.0,
                        color: Colors.grey[400], // Placeholder color
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: const CircleAvatar(
                        radius: 20.0,
                        backgroundColor: Colors.grey, // Placeholder color
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  // Handle add to itinerary
                },
                icon: const Icon(Icons.add),
                label: const Text('Add to my itinerary'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    side: const BorderSide(color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 8.0),
              ElevatedButton.icon(
                onPressed: () {
                  // Handle 12 mins from hotel
                },
                icon: const Icon(Icons.location_on),
                label: const Text('12 mins from hotel'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    side: const BorderSide(color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DoctorCard extends StatelessWidget {
  const DoctorCard({
    super.key,
    required this.name,
    required this.specialty,
    required this.ratingAndDistance,
    required this.description,
  });

  final String name;
  final String specialty;
  final String ratingAndDistance;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.grey[300]!),
      ),
      padding: const EdgeInsets.all(12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Placeholder for the abstract shapes (same as in the main card)
          SizedBox(
            width: 60.0,
            height: 50.0,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: 20.0,
                    height: 15.0,
                    color: Colors.grey[400], // Placeholder color
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 15.0,
                    height: 15.0,
                    color: Colors.grey[400], // Placeholder color
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: const CircleAvatar(
                    radius: 15.0,
                    backgroundColor: Colors.grey, // Placeholder color
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  specialty,
                  style: const TextStyle(color: Colors.grey, fontSize: 14.0),
                ),
                Text(
                  ratingAndDistance,
                  style: const TextStyle(color: Colors.grey, fontSize: 12.0),
                ),
                const SizedBox(height: 4.0),
                Text(
                  description,
                  style: const TextStyle(color: Colors.grey, fontSize: 12.0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}