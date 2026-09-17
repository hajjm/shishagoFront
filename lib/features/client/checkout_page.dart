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
  bool bringChange = false;
  bool loadingQuote = false;
  DeliveryAvailability? deliveryQuote;
  String? quoteError;

  @override
  void initState() {
    super.initState();
    _selectInitialLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) => refreshDeliveryQuote());
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

  Future<void> refreshDeliveryQuote() async {
    final location = selectedLocation;
    if (location == null) {
      if (mounted) setState(() => deliveryQuote = null);
      return;
    }
    final locationId = location.id;
    setState(() {
      loadingQuote = true;
      quoteError = null;
      deliveryQuote = null;
    });
    try {
      final result = await widget.store.checkDeliveryAvailability(location);
      if (!mounted || selectedLocationId != locationId) return;
      setState(() => deliveryQuote = result);
    } catch (error) {
      if (!mounted || selectedLocationId != locationId) return;
      setState(() => quoteError = error.toString());
    } finally {
      if (mounted && selectedLocationId == locationId) {
        setState(() => loadingQuote = false);
      }
    }
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
      await refreshDeliveryQuote();
    }
  }

  Future<void> editLocation(SavedLocation existing) async {
    final location = await showEditDeliveryLocation(
      context,
      widget.store,
      existing,
    );
    if (location != null && mounted) {
      setState(() => selectedLocationId = location.id);
      await refreshDeliveryQuote();
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
    await refreshDeliveryQuote();
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
      setState(() => deliveryQuote = availability);
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
          '${location.label} — ${location.address}?'
          '${bringChange ? '\n\nThe driver will be told to bring change.' : ''}',
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
        bringChange: bringChange,
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
                onTap: () async {
                  setState(() => selectedLocationId = location.id);
                  await refreshDeliveryQuote();
                },
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
                          if (action == 'edit') {
                            await editLocation(location);
                          } else if (action == 'default') {
                            await widget.store.setDefaultLocation(location);
                          } else if (action == 'delete') {
                            await removeLocation(location);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.edit_location_alt_outlined),
                              title: Text('Edit location'),
                            ),
                          ),
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
              color: deliveryQuote?.available == true
                  ? Colors.green.withValues(alpha: 0.08)
                  : Colors.red.withValues(alpha: 0.08),
              child: ListTile(
                dense: true,
                leading: Icon(
                  deliveryQuote?.available == true
                      ? Icons.check_circle_rounded
                      : loadingQuote
                      ? Icons.hourglass_top_rounded
                      : Icons.location_off_rounded,
                  color: deliveryQuote?.available == true
                      ? Colors.green
                      : Colors.red,
                ),
                title: Text(
                  loadingQuote
                      ? 'Calculating delivery charge…'
                      : deliveryQuote?.available == true
                      ? 'Delivery available in ${deliveryQuote!.zone!.name}'
                      : 'Outside the current delivery or pricing area',
                ),
                subtitle: Text(
                  quoteError ??
                      (deliveryQuote?.available == true
                          ? '${deliveryQuote!.distanceKm!.toStringAsFixed(1)} km from the store · '
                                '\$${deliveryQuote!.deliveryFee!.toStringAsFixed(2)} delivery'
                          : 'Choose a different delivery point.'),
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: bringChange,
            onChanged: (value) => setState(() => bringChange = value ?? false),
            title: const Text('Ask the driver to bring change'),
            subtitle: const Text(
              'Select this if you will pay cash and need change.',
            ),
            secondary: const Icon(Icons.payments_outlined),
          ),
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
                  _PriceRow(
                    label: 'Delivery',
                    value: deliveryQuote?.deliveryFee ?? 0,
                  ),
                  const Divider(height: 24),
                  _PriceRow(
                    label: 'Total',
                    value:
                        widget.store.cartTotal +
                        (deliveryQuote?.deliveryFee ?? 0),
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
                    loadingQuote ||
                    selectedLocation == null ||
                    deliveryQuote?.available != true
                ? null
                : placeOrder,
            icon: submitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_rounded),
            label: Text(submitting ? 'Placing order…' : 'Confirm order'),
          ),
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

Future<SavedLocation?> showEditDeliveryLocation(
  BuildContext context,
  ShishaGoStore store,
  SavedLocation location,
) => showDialog<SavedLocation>(
  context: context,
  builder: (_) => _AddDeliveryLocationDialog(store: store, existing: location),
);

class _AddDeliveryLocationDialog extends StatefulWidget {
  const _AddDeliveryLocationDialog({required this.store, this.existing});

  final ShishaGoStore store;
  final SavedLocation? existing;

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
  GoogleMapController? mapController;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null) {
      makeDefault = widget.store.savedLocations.isEmpty;
    } else {
      labelController.text = existing.label;
      addressController.text = existing.address;
      coordinates = CapturedLocation(
        latitude: existing.latitude,
        longitude: existing.longitude,
      );
      makeDefault = existing.isDefault;
    }
  }

  @override
  void dispose() {
    mapController?.dispose();
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
      await mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(value.latitude, value.longitude), 16),
      );
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
      setState(
        () => error = 'Use your current position or select a pin on the map.',
      );
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final existing = widget.existing;
      final location = existing == null
          ? await widget.store.addSavedLocation(
              label: labelController.text.trim(),
              address: addressController.text.trim(),
              latitude: selectedCoordinates.latitude,
              longitude: selectedCoordinates.longitude,
              isDefault: makeDefault,
            )
          : await widget.store.updateSavedLocation(
              existing: existing,
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
    title: Text(
      widget.existing == null
          ? 'Add delivery location'
          : 'Edit delivery location',
    ),
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
              const SizedBox(height: 10),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Or tap the map to choose the exact delivery point',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 230,
                  child: GoogleMap(
                    onMapCreated: (controller) => mapController = controller,
                    initialCameraPosition: CameraPosition(
                      target: coordinates == null
                          ? const LatLng(33.8938, 35.5018)
                          : LatLng(
                              coordinates!.latitude,
                              coordinates!.longitude,
                            ),
                      zoom: coordinates == null ? 12 : 16,
                    ),
                    mapToolbarEnabled: false,
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    onTap: (position) => setState(
                      () => coordinates = CapturedLocation(
                        latitude: position.latitude,
                        longitude: position.longitude,
                      ),
                    ),
                    markers: coordinates == null
                        ? const <Marker>{}
                        : {
                            Marker(
                              markerId: const MarkerId(
                                'delivery-location-editor',
                              ),
                              draggable: true,
                              onDragEnd: (position) => setState(
                                () => coordinates = CapturedLocation(
                                  latitude: position.latitude,
                                  longitude: position.longitude,
                                ),
                              ),
                              position: LatLng(
                                coordinates!.latitude,
                                coordinates!.longitude,
                              ),
                            ),
                          },
                    circles: widget.store.deliveryZones
                        .where((zone) => zone.isActive)
                        .map(
                          (zone) => Circle(
                            circleId: CircleId('editor-${zone.id}'),
                            center: LatLng(
                              zone.centerLatitude,
                              zone.centerLongitude,
                            ),
                            radius: zone.radiusKm * 1000,
                            fillColor: AppColors.ember.withValues(alpha: 0.08),
                            strokeColor: AppColors.ember,
                            strokeWidth: 2,
                          ),
                        )
                        .toSet(),
                  ),
                ),
              ),
              if (coordinates != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Selected pin: ${coordinates!.label}',
                    style: const TextStyle(color: AppColors.muted),
                  ),
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
