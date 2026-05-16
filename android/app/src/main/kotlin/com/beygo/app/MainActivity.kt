package com.beygo.app

import android.content.pm.PackageManager
import com.google.android.gms.maps.model.LatLng
import com.google.android.libraries.places.api.Places
import com.google.android.libraries.places.api.model.Place
import com.google.android.libraries.places.api.model.RectangularBounds
import com.google.android.libraries.places.api.net.FetchPlaceRequest
import com.google.android.libraries.places.api.net.FetchPlaceResponse
import com.google.android.libraries.places.api.net.FindAutocompletePredictionsRequest
import com.google.android.libraries.places.api.net.FindAutocompletePredictionsResponse
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val envChannelName = "beygo/env"
    private val placesChannelName = "beygo/places"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            envChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "googleMapsKey" -> {
                    try {
                        val appInfo = packageManager.getApplicationInfo(
                            packageName,
                            PackageManager.GET_META_DATA
                        )
                        val key = appInfo.metaData
                            ?.getString("com.google.android.geo.API_KEY")
                            ?.trim()
                            .orEmpty()
                        result.success(key)
                    } catch (e: Exception) {
                        result.success("")
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            placesChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "autocomplete" -> {
                    val input = call.argument<String>("input")?.trim().orEmpty()
                    val countryCode = call.argument<String>("countryCode")?.trim()?.uppercase().orEmpty()
                    val latitude = call.argument<Double>("latitude")
                    val longitude = call.argument<Double>("longitude")
                    val radiusMeters = call.argument<Int>("radiusMeters")?.toDouble()
                    if (input.isEmpty()) {
                        result.success(emptyList<Map<String, Any?>>())
                        return@setMethodCallHandler
                    }

                    val client = placesClientOrNull()
                    if (client == null) {
                        result.error("places_unavailable", "Google Places SDK is not initialized.", null)
                        return@setMethodCallHandler
                    }

                    val requestBuilder = FindAutocompletePredictionsRequest.builder()
                        .setQuery(input)

                    if (countryCode.isNotEmpty()) {
                        requestBuilder.setCountries(listOf(countryCode))
                    }

                    if (latitude != null && longitude != null) {
                        val origin = LatLng(latitude, longitude)
                        requestBuilder.setOrigin(origin)

                        if (radiusMeters != null && radiusMeters > 0) {
                            val latDelta = radiusMeters / 111_320.0
                            val lngDelta = radiusMeters / (111_320.0 * kotlin.math.cos(Math.toRadians(latitude)).coerceAtLeast(0.01))
                            val southwest = LatLng(latitude - latDelta, longitude - lngDelta)
                            val northeast = LatLng(latitude + latDelta, longitude + lngDelta)
                            requestBuilder.setLocationBias(
                                RectangularBounds.newInstance(southwest, northeast)
                            )
                        }
                    }

                    client.findAutocompletePredictions(requestBuilder.build())
                        .addOnSuccessListener { response: FindAutocompletePredictionsResponse ->
                            val items = response.autocompletePredictions.map { prediction ->
                                mapOf(
                                    "placeId" to prediction.placeId,
                                    "mainText" to prediction.getPrimaryText(null).toString(),
                                    "secondaryText" to prediction.getSecondaryText(null).toString(),
                                    "fullText" to prediction.getFullText(null).toString(),
                                    "types" to prediction.placeTypes.map { it.name.lowercase() }
                                )
                            }
                            result.success(items)
                        }
                        .addOnFailureListener { error ->
                            result.error("places_autocomplete_failed", error.message, null)
                        }
                }

                "fetchPlaceLocation" -> {
                    val placeId = call.argument<String>("placeId")?.trim().orEmpty()
                    if (placeId.isEmpty()) {
                        result.success(null)
                        return@setMethodCallHandler
                    }

                    val client = placesClientOrNull()
                    if (client == null) {
                        result.error("places_unavailable", "Google Places SDK is not initialized.", null)
                        return@setMethodCallHandler
                    }

                    val request = FetchPlaceRequest.newInstance(
                        placeId,
                        listOf(Place.Field.ID, Place.Field.LAT_LNG, Place.Field.NAME, Place.Field.ADDRESS)
                    )

                    client.fetchPlace(request)
                        .addOnSuccessListener { response: FetchPlaceResponse ->
                            val place = response.place
                            val latLng: LatLng? = place.latLng
                            if (latLng == null) {
                                result.success(null)
                            } else {
                                result.success(
                                    mapOf(
                                        "lat" to latLng.latitude,
                                        "lng" to latLng.longitude,
                                        "name" to place.name,
                                        "address" to place.address
                                    )
                                )
                            }
                        }
                        .addOnFailureListener { error ->
                            result.error("places_details_failed", error.message, null)
                        }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun placesClientOrNull() = try {
        val appInfo = packageManager.getApplicationInfo(
            packageName,
            PackageManager.GET_META_DATA
        )
        val key = appInfo.metaData
            ?.getString("com.google.android.geo.API_KEY")
            ?.trim()
            .orEmpty()

        if (key.isEmpty()) {
            null
        } else {
            if (!Places.isInitialized()) {
                Places.initialize(applicationContext, key)
            }
            Places.createClient(this)
        }
    } catch (_: Exception) {
        null
    }
}
