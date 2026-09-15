import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/app_theme.dart';
import '../../data/app_store.dart';
import '../../models/app_models.dart';
import '../../services/device_location_service.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key, required this.store});

  final ShishaGoStore store;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final notesController = TextEditingController();
  String? selectedLocationId;
  bool submitting = false;

  @override
  void initState() {
    super.initState();
    _selectInitialLocation();
  }

  void _selectInitialLocation() {
    if (widget.store.savedLocations.isEmpty) return;
    final defaultLocation = widget.store.savedLocations.where(
      (location) => location.isDefault,
    );
    selectedLocationId = defaultLocation.isNotEmpty
        ? defaultLocation.first.id
        : widget.store.savedLocations.first.id;
  }

  SavedLocation? get selectedLocation {
    for (final location in widget.store.savedLocations) {
      if (location.id == selectedLocationId) return location;
    }
    return null;
  }

  DeliveryZone? get selectedDeliveryZone {
    final location = selectedLocation;
    return location == null ? null : widget.store.deliveryZoneFor(location);
  }

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  Future<void> addLocation() async {
    final location = await showAddDeliveryLocation(context, widget.store);
    if (location != null && mounted) {
      setState(() => selectedLocationId = location.id);
    }
  }

  Future<void> removeLocation(SavedLocation location) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${location.label}?'),
        content: Text(location.address),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.store.deleteSavedLocation(location);
    if (!mounted) return;
    setState(_selectInitialLocation);
  }

  Future<void> placeOrder() async {
    final location = selectedLocation;
    if (location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select or add a delivery location')),
      );
      return;
    }
    try {
      final availability = await widget.store.checkDeliveryAvailability(
        location,
      );
      if (!mounted) return;
      if (!availability.available) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This location is outside the current Shisha Go delivery area.',
            ),
          ),
        );
        return;
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.location_on_rounded, color: AppColors.ember),
        title: const Text('Confirm delivery location'),
        content: Text(
          'Are you sure you want this Shisha Go order sent to '
          '${location.label} — ${location.address}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Review'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, place order'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => submitting = true);
    try {
      final order = await widget.store.checkout(
        location: location,
        notes: notesController.text.trim(),
      );
      if (mounted) Navigator.pop(context, order);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
        setState(() => submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Checkout')),
    body: AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Review your items',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          ...widget.store.cartLines.map(
            (line) => Card(
              child: ListTile(
                leading: CircleAvatar(child: Icon(line.product.icon)),
                title: Text('${line.quantity} × ${line.product.name}'),
                subtitle: line.customizationSummary.isEmpty
                    ? null
                    : Text(line.customizationSummary),
                trailing: Text(
                  '\$${line.total.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Delivery location',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton.icon(
                onPressed: addLocation,
                icon: const Icon(Icons.add_location_alt_rounded),
                label: const Text('Add'),
              ),
            ],
          ),
          const Text(
            'Choose exactly where this order should be delivered.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          if (widget.store.savedLocations.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    const Text('You have no saved delivery locations.'),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: addLocation,
                      icon: const Icon(Icons.my_location_rounded),
                      label: const Text('Add a location'),
                    ),
                  ],
                ),
              ),
            ),
          ...widget.store.savedLocations.map(
            (location) => Card(
              color: selectedLocationId == location.id
                  ? AppColors.sand.withValues(alpha: 0.65)
                  : null,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => setState(() => selectedLocationId = location.id),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        selectedLocationId == location.id
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: selectedLocationId == location.id
                            ? AppColors.ember
                            : AppColors.muted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  location.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (location.isDefault) ...[
                                  const SizedBox(width: 7),
                                  const Chip(label: Text('Default')),
                                ],
                              ],
                            ),
                            Text(location.address),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (action) async {
                          if (action == 'default') {
                            await widget.store.setDefaultLocation(location);
                          } else if (action == 'delete') {
                            await removeLocation(location);
                          }
                        },
                        itemBuilder: (context) => [
                          if (!location.isDefault)
                            const PopupMenuItem(
                              value: 'default',
                              child: Text('Make default'),
                            ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Remove'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (selectedLocation case final location?) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 220,
                child: GoogleMap(
                  key: ValueKey(location.id),
                  initialCameraPosition: CameraPosition(
                    target: LatLng(location.latitude, location.longitude),
                    zoom: 12,
                  ),
                  mapToolbarEnabled: false,
                  zoomControlsEnabled: false,
                  markers: {
                    Marker(
                      markerId: const MarkerId('selected-delivery-location'),
                      position: LatLng(location.latitude, location.longitude),
                      infoWindow: InfoWindow(
                        title: location.label,
                        snippet: location.address,
                      ),
                    ),
                  },
                  circles: widget.store.deliveryZones
                      .where((zone) => zone.isActive)
                      .map(
                        (zone) => Circle(
                          circleId: CircleId(zone.id),
                          center: LatLng(
                            zone.centerLatitude,
                            zone.centerLongitude,
                          ),
                          radius: zone.radiusKm * 1000,
                          fillColor: AppColors.ember.withValues(alpha: 0.10),
                          strokeColor: AppColors.ember,
                          strokeWidth: 2,
                        ),
                      )
                      .toSet(),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Card(
              color: selectedDeliveryZone == null
                  ? Colors.red.withValues(alpha: 0.08)
                  : Colors.green.withValues(alpha: 0.08),
              child: ListTile(
                dense: true,
                leading: Icon(
                  selectedDeliveryZone == null
                      ? Icons.location_off_rounded
                      : Icons.check_circle_rounded,
                  color: selectedDeliveryZone == null
                      ? Colors.red
                      : Colors.green,
                ),
                title: Text(
                  selectedDeliveryZone == null
                      ? 'Outside the current delivery area'
                      : 'Delivery available in ${selectedDeliveryZone!.name}',
                ),
                subtitle: const Text(
                  'Confirm that this pin is your intended delivery point.',
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          TextField(
            controller: notesController,
            maxLength: 500,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Delivery notes (optional)',
              hintText: 'Building, floor, landmark…',
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _PriceRow(label: 'Items', value: widget.store.cartTotal),
                  const _PriceRow(label: 'Delivery', value: 2),
                  const Divider(height: 24),
                  _PriceRow(
                    label: 'Total',
                    value: widget.store.cartTotal + 2,
                    emphasized: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed:
                submitting ||
                    selectedLocation == null ||
                    selectedDeliveryZone == null
                ? null
                : placeOrder,
            icon: submitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline_rounded),
            label: const Text('Confirm order'),
          ),
          const SizedBox(height: 30),
        ],
      ),
    ),
  );
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final double value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label)),
      Text(
        '\$${value.toStringAsFixed(2)}',
        style: TextStyle(
          fontWeight: emphasized ? FontWeight.w900 : FontWeight.w600,
          fontSize: emphasized ? 18 : null,
        ),
      ),
    ],
  );
}

Future<SavedLocation?> showAddDeliveryLocation(
  BuildContext context,
  ShishaGoStore store,
) => showDialog<SavedLocation>(
  context: context,
  builder: (_) => _AddDeliveryLocationDialog(store: store),
);

class _AddDeliveryLocationDialog extends StatefulWidget {
  const _AddDeliveryLocationDialog({required this.store});

  final ShishaGoStore store;

  @override
  State<_AddDeliveryLocationDialog> createState() =>
      _AddDeliveryLocationDialogState();
}

class _AddDeliveryLocationDialogState
    extends State<_AddDeliveryLocationDialog> {
  final formKey = GlobalKey<FormState>();
  final labelController = TextEditingController();
  final addressController = TextEditingController();
  CapturedLocation? coordinates;
  bool capturing = false;
  bool saving = false;
  late bool makeDefault;
  String? error;

  @override
  void initState() {
    super.initState();
    makeDefault = widget.store.savedLocations.isEmpty;
  }

  @override
  void dispose() {
    labelController.dispose();
    addressController.dispose();
    super.dispose();
  }

  Future<void> captureLocation() async {
    setState(() {
      capturing = true;
      error = null;
    });
    try {
      final value = await const DeviceLocationService().captureCurrent();
      if (!mounted) return;
      setState(() => coordinates = value);
    } catch (exception) {
      if (!mounted) return;
      setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => capturing = false);
    }
  }

  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final selectedCoordinates = coordinates;
    if (selectedCoordinates == null) {
      setState(() => error = 'Capture the GPS position for this address.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final location = await widget.store.addSavedLocation(
        label: labelController.text.trim(),
        address: addressController.text.trim(),
        latitude: selectedCoordinates.latitude,
        longitude: selectedCoordinates.longitude,
        isDefault: makeDefault,
      );
      if (mounted) Navigator.pop(context, location);
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        saving = false;
        error = exception.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add delivery location'),
    content: SizedBox(
      width: 430,
      child: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: labelController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Label',
                  hintText: 'Home, Work, Friend…',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a label'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Address details',
                  hintText: 'Street, building, floor',
                ),
                validator: (value) => value == null || value.trim().length < 3
                    ? 'Enter the delivery address'
                    : null,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: capturing ? null : captureLocation,
                icon: const Icon(Icons.my_location_rounded),
                label: Text(
                  coordinates == null
                      ? 'Use current GPS position'
                      : 'GPS captured — update',
                ),
              ),
              if (coordinates != null)
                Text(
                  coordinates!.label,
                  style: const TextStyle(color: AppColors.muted),
                ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: makeDefault,
                onChanged: (value) =>
                    setState(() => makeDefault = value ?? false),
                title: const Text('Use as my default location'),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: saving ? null : save,
        child: Text(saving ? 'Saving…' : 'Save location'),
      ),
    ],
  );
}
