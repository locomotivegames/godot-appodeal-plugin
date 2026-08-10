package com.slyd4r.appodealnative

import android.app.Activity
import android.graphics.Color
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import com.appodeal.ads.Appodeal
import com.appodeal.ads.BannerCallbacks
import com.appodeal.ads.InterstitialCallbacks
import com.appodeal.ads.NativeAd
import com.appodeal.ads.NativeCallbacks
import com.appodeal.ads.RewardedVideoCallbacks
import com.appodeal.ads.nativead.NativeAdViewNewsFeed
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import com.appodeal.ads.nativead.NativeAdViewAppWall
import com.appodeal.ads.nativead.NativeAdViewContentStream
import com.appodeal.ads.nativead.NativeAdView
import com.appodeal.consent.ConsentManager
import com.appodeal.consent.ConsentUpdateRequestParameters
import com.appodeal.consent.ConsentInfoUpdateCallback
import com.appodeal.consent.ConsentManagerError
import com.appodeal.consent.OnConsentFormDismissedListener
import com.google.android.ump.ConsentDebugSettings
import com.google.android.ump.ConsentRequestParameters
import com.google.android.ump.UserMessagingPlatform

class GodotAndroidPlugin(godot: Godot) : GodotPlugin(godot) {

    // for UMP debugging and test device settings:
    private var consentTestDeviceHashedIds: List<String> = emptyList()
    private var forceConsentEea: Boolean = false
    private var resetConsentForTesting: Boolean = false
    //end
    private val tag = "AppodealNative"

    private var initialized = false

    private var nativeAdView: NativeAdView? = null
    private var bannerView: View? = null

    private var currentNativeTemplateType: Int = -1
    override fun getPluginName(): String {
        return "AppodealNative"
    }

    fun setConsentDebugSettings(
        hashedIdsCsv: String,
        forceEea: Boolean,
        reset: Boolean
    ) {
        consentTestDeviceHashedIds = hashedIdsCsv
            .split(",")
            .map { it.trim() }
            .filter { it.isNotEmpty() }

        forceConsentEea = forceEea
        resetConsentForTesting = reset

        Log.d(pluginName, "Consent debug ids count=${consentTestDeviceHashedIds.size}, forceEea=$forceConsentEea, reset=$resetConsentForTesting")
    }

    @UsedByGodot
    fun load_and_show_consent_form_if_required() {
        val currentActivity = activity ?: return

        currentActivity.runOnUiThread {
            try {
                ConsentManager.loadAndShowConsentFormIfRequired(
                    activity = currentActivity,
                    dismissedListener = object : OnConsentFormDismissedListener {
                        override fun onConsentFormDismissed(error: ConsentManagerError?) {
                            if (error == null) {
                                Log.d(tag, "Consent form dismissed successfully")
                                emitToGodot("consent_form_dismissed", true, "")
                            } else {
                                Log.e(tag, "Consent form dismissed with error: $error")
                                emitToGodot("consent_form_dismissed", false, error.toString())
                            }
                        }
                    }
                )
            } catch (e: Throwable) {
                Log.e(tag, "load_and_show_consent_form_if_required error: ${e.message}", e)
                emitToGodot("consent_form_dismissed", false, e.message ?: "Unknown error")
            }
        }
    }
    @UsedByGodot
    fun get_consent_status(): String {
        return try {
            ConsentManager.status.toString()
        } catch (e: Throwable) {
            "Error: ${e.message}"
        }
    }
    @UsedByGodot
    fun can_show_ads_after_consent(): Boolean {
        return try {
            ConsentManager.canShowAds()
        } catch (e: Throwable) {
            false
        }
    }


    @UsedByGodot
    fun request_consent_info_update(appKey: String, tagForUnderAgeOfConsent: Boolean) {
        val currentActivity = activity ?: return

        currentActivity.runOnUiThread {
            try {
                ConsentManager.requestConsentInfoUpdate(
                    parameters = ConsentUpdateRequestParameters(
                        activity = currentActivity,
                        key = appKey,
                        tagForUnderAgeOfConsent = tagForUnderAgeOfConsent,
                        sdk = "Appodeal",
                        sdkVersion = Appodeal.getVersion()
                    ),
                    callback = object : ConsentInfoUpdateCallback {
                        override fun onUpdated() {
                            val status = ConsentManager.status.toString()
                            Log.d(tag, "Consent info updated: $status")
                            emitToGodot("consent_info_updated", true, status)
                        }

                        override fun onFailed(error: ConsentManagerError) {
                            Log.e(tag, "Consent info update failed: $error")
                            emitToGodot("consent_info_updated", false, error.toString())
                        }
                    }
                )
            } catch (e: Throwable) {
                Log.e(tag, "request_consent_info_update error: ${e.message}", e)
                emitToGodot("consent_info_updated", false, e.message ?: "Unknown error")
            }
        }
    }

    @UsedByGodot
    fun request_ump_debug_consent_flow(
        hashedId: String,
        tagForUnderAgeOfConsent: Boolean,
        forceEea: Boolean,
        reset: Boolean
    ) {
        val currentActivity = activity ?: return

        currentActivity.runOnUiThread {
            try {
                val consentInformation = UserMessagingPlatform.getConsentInformation(currentActivity)

                if (reset) {
                    consentInformation.reset()
                }

                val debugSettingsBuilder = ConsentDebugSettings.Builder(currentActivity)
                    .addTestDeviceHashedId(hashedId)

                if (forceEea) {
                    debugSettingsBuilder.setDebugGeography(
                        ConsentDebugSettings.DebugGeography.DEBUG_GEOGRAPHY_EEA
                    )
                }

                val params = ConsentRequestParameters.Builder()
                    .setTagForUnderAgeOfConsent(tagForUnderAgeOfConsent)
                    .setConsentDebugSettings(debugSettingsBuilder.build())
                    .build()

                consentInformation.requestConsentInfoUpdate(
                    currentActivity,
                    params,
                    {
                        Log.d(tag, "UMP debug consent info updated")

                        UserMessagingPlatform.loadAndShowConsentFormIfRequired(
                            currentActivity
                        ) { formError ->
                            if (formError != null) {
                                Log.e(tag, "UMP consent form error: ${formError.message}")
                                emitToGodot(
                                    "consent_flow_finished",
                                    false,
                                    formError.message ?: "Consent form error"
                                )
                            } else {
                                Log.d(tag, "UMP consent flow finished")
                                emitToGodot(
                                    "consent_flow_finished",
                                    true,
                                    consentInformation.consentStatus.toString()
                                )
                            }
                        }
                    },
                    { error ->
                        Log.e(tag, "UMP consent info update failed: ${error.message}")
                        emitToGodot(
                            "consent_flow_finished",
                            false,
                            error.message ?: "UMP consent update failed"
                        )
                    }
                )
            } catch (e: Throwable) {
                Log.e(tag, "request_ump_debug_consent_flow error: ${e.message}", e)
                emitToGodot("consent_flow_finished", false, e.message ?: "Unknown error")
            }
        }
    }
    override fun getPluginSignals(): Set<SignalInfo> {
        return setOf(

            SignalInfo("consent_info_updated", Boolean::class.javaObjectType, String::class.java),
            SignalInfo("consent_form_dismissed", Boolean::class.javaObjectType, String::class.java),
            SignalInfo("privacy_options_status", String::class.java),

            SignalInfo("initialization_finished", Boolean::class.javaObjectType, String::class.java),

            SignalInfo("banner_loaded", Long::class.javaObjectType, Boolean::class.javaObjectType),
            SignalInfo("banner_failed_to_load"),
            SignalInfo("banner_shown"),
            SignalInfo("banner_show_failed"),
            SignalInfo("banner_clicked"),
            SignalInfo("banner_expired"),
            SignalInfo("banner_hidden"),
            SignalInfo(
                "banner_position_updated",
                Long::class.javaObjectType,
                Long::class.javaObjectType,
                Long::class.javaObjectType,
                Long::class.javaObjectType
            ),

            SignalInfo("interstitial_loaded", Boolean::class.javaObjectType),
            SignalInfo("interstitial_failed_to_load"),
            SignalInfo("interstitial_shown"),
            SignalInfo("interstitial_show_failed"),
            SignalInfo("interstitial_clicked"),
            SignalInfo("interstitial_closed"),
            SignalInfo("interstitial_expired"),

            SignalInfo("rewarded_loaded", Boolean::class.javaObjectType),
            SignalInfo("rewarded_failed_to_load"),
            SignalInfo("rewarded_shown"),
            SignalInfo("rewarded_show_failed"),
            SignalInfo("rewarded_clicked"),
            SignalInfo("rewarded_finished", Double::class.javaObjectType, String::class.java),
            SignalInfo("rewarded_closed", Boolean::class.javaObjectType),
            SignalInfo("rewarded_expired"),

            SignalInfo("native_loaded", Long::class.javaObjectType),
            SignalInfo("native_failed_to_load"),
            SignalInfo("native_shown"),
            SignalInfo("native_show_failed"),
            SignalInfo("native_clicked"),
            SignalInfo("native_expired"),
            SignalInfo("native_hidden"),
            SignalInfo(
                "native_position_updated",
                Long::class.javaObjectType,
                Long::class.javaObjectType,
                Long::class.javaObjectType,
                Long::class.javaObjectType
            ),
            SignalInfo("consent_flow_finished", Boolean::class.javaObjectType, String::class.java)

        )
    }

    private fun emitToGodot(signalName: String, vararg args: Any?) {
        try {
            emitSignal(signalName, *args)
        } catch (e: Throwable) {
            Log.e(tag, "Failed to emit signal $signalName: ${e.message}", e)
        }
    }
    private fun createNativeTemplateView(templateType: Int, activity: Activity): NativeAdView {
        return when (templateType) {
            1 -> NativeAdViewAppWall(activity)
            2 -> NativeAdViewContentStream(activity)
            else -> NativeAdViewNewsFeed(activity)
        }
    }
    private fun adTypesAll(): Int {
        return Appodeal.BANNER or
            Appodeal.INTERSTITIAL or
            Appodeal.REWARDED_VIDEO or
            Appodeal.NATIVE
    }

    private fun getRootView(activity: Activity): ViewGroup {
        return activity.findViewById(android.R.id.content)
    }

    @UsedByGodot
    fun initialize(appKey: String, testing: Boolean, autoCache: Boolean) {
        val currentActivity = activity

        Log.d(tag, "initialize called")

        if (currentActivity == null) {
            Log.e(tag, "Activity is null")
            emitToGodot("initialization_finished", false, "Activity is null")
            return
        }

        currentActivity.runOnUiThread {
            try {
                if (initialized) {
                    Log.d(tag, "Appodeal already initialized")
                    emitToGodot("initialization_finished", true, "")
                    return@runOnUiThread
                }

                Log.d(tag, "Before Appodeal.setTesting")
                Appodeal.setTesting(testing)

                if (!autoCache) {
                    Appodeal.setAutoCache(Appodeal.BANNER, false)
                    Appodeal.setAutoCache(Appodeal.INTERSTITIAL, false)
                    Appodeal.setAutoCache(Appodeal.REWARDED_VIDEO, false)
                    Appodeal.setAutoCache(Appodeal.NATIVE, false)
                }

                setupCallbacks()

                Log.d(tag, "Before Appodeal.initialize")
                val adTypes = Appodeal.BANNER or
                        Appodeal.INTERSTITIAL or
                        Appodeal.REWARDED_VIDEO or
                        Appodeal.NATIVE

                Log.d(tag, "Before Appodeal.initialize")

                Appodeal.initialize(
                    currentActivity,
                    appKey,
                    adTypes
                ) { errors ->

                    // Important: callback reached = SDK is usable
                    initialized = true

                    if (errors.isNullOrEmpty()) {
                        Log.d(tag, "Appodeal initialized successfully")
                        emitToGodot("initialization_finished", true, "")
                    } else {
                        val message = errors.joinToString(separator = " | ") { it.toString() }

                        Log.e(tag, "Appodeal initialized with warnings/errors: $message")

                        // Still success=true because ads can load even with config warnings
                        emitToGodot("initialization_finished", true, message)
                    }
                }

                Log.d(tag, "After Appodeal.initialize call")


            } catch (e: Throwable) {
                val message = e.message ?: "Unknown initialization error"
                Log.e(tag, "initialize fatal error: $message", e)
                emitToGodot("initialization_finished", false, message)
            }
        }
    }

    private fun setupCallbacks() {
        Appodeal.setBannerCallbacks(object : BannerCallbacks {
            override fun onBannerLoaded(height: Int, isPrecache: Boolean) {
                Log.d(tag, "onBannerLoaded: height=$height, isPrecache=$isPrecache")
                emitToGodot("banner_loaded", height.toLong(), java.lang.Boolean.valueOf(isPrecache))
            }

            override fun onBannerFailedToLoad() {
                Log.e(tag, "onBannerFailedToLoad")
                emitToGodot("banner_failed_to_load")
            }

            override fun onBannerShown() {
                Log.d(tag, "onBannerShown")
                emitToGodot("banner_shown")
            }

            override fun onBannerShowFailed() {
                Log.e(tag, "onBannerShowFailed")
                emitToGodot("banner_show_failed")
            }

            override fun onBannerClicked() {
                Log.d(tag, "onBannerClicked")
                emitToGodot("banner_clicked")
            }

            override fun onBannerExpired() {
                Log.w(tag, "onBannerExpired")
                emitToGodot("banner_expired")
            }
        })

        Appodeal.setInterstitialCallbacks(object : InterstitialCallbacks {
            override fun onInterstitialLoaded(isPrecache: Boolean) {
                Log.d(tag, "onInterstitialLoaded: isPrecache=$isPrecache")
                emitToGodot("interstitial_loaded", java.lang.Boolean.valueOf(isPrecache))
            }

            override fun onInterstitialFailedToLoad() {
                Log.e(tag, "onInterstitialFailedToLoad")
                emitToGodot("interstitial_failed_to_load")
            }

            override fun onInterstitialShown() {
                Log.d(tag, "onInterstitialShown")
                emitToGodot("interstitial_shown")
            }

            override fun onInterstitialShowFailed() {
                Log.e(tag, "onInterstitialShowFailed")
                emitToGodot("interstitial_show_failed")
            }

            override fun onInterstitialClicked() {
                Log.d(tag, "onInterstitialClicked")
                emitToGodot("interstitial_clicked")
            }

            override fun onInterstitialClosed() {
                Log.d(tag, "onInterstitialClosed")
                emitToGodot("interstitial_closed")
            }

            override fun onInterstitialExpired() {
                Log.w(tag, "onInterstitialExpired")
                emitToGodot("interstitial_expired")
            }
        })

        Appodeal.setRewardedVideoCallbacks(object : RewardedVideoCallbacks {
            override fun onRewardedVideoLoaded(isPrecache: Boolean) {
                Log.d(tag, "onRewardedVideoLoaded: isPrecache=$isPrecache")
                emitToGodot("rewarded_loaded", java.lang.Boolean.valueOf(isPrecache))
            }

            override fun onRewardedVideoFailedToLoad() {
                Log.e(tag, "onRewardedVideoFailedToLoad")
                emitToGodot("rewarded_failed_to_load")
            }

            override fun onRewardedVideoShown() {
                Log.d(tag, "onRewardedVideoShown")
                emitToGodot("rewarded_shown")
            }

            override fun onRewardedVideoShowFailed() {
                Log.e(tag, "onRewardedVideoShowFailed")
                emitToGodot("rewarded_show_failed")
            }

            override fun onRewardedVideoClicked() {
                Log.d(tag, "onRewardedVideoClicked")
                emitToGodot("rewarded_clicked")
            }

            override fun onRewardedVideoFinished(amount: Double, currency: String) {
                Log.d(tag, "onRewardedVideoFinished: amount=$amount, currency=$currency")
                emitToGodot("rewarded_finished", amount, currency)
            }

            override fun onRewardedVideoClosed(finished: Boolean) {
                Log.d(tag, "onRewardedVideoClosed: finished=$finished")
                emitToGodot("rewarded_closed", java.lang.Boolean.valueOf(finished))
            }

            override fun onRewardedVideoExpired() {
                Log.w(tag, "onRewardedVideoExpired")
                emitToGodot("rewarded_expired")
            }
        })

        Appodeal.setNativeCallbacks(object : NativeCallbacks {
            override fun onNativeLoaded() {
                val count = Appodeal.getAvailableNativeAdsCount()
                Log.d(tag, "onNativeLoaded: count=$count")
                emitToGodot("native_loaded", count.toLong())
            }

            override fun onNativeFailedToLoad() {
                Log.e(tag, "onNativeFailedToLoad")
                emitToGodot("native_failed_to_load")
            }

            override fun onNativeShown(nativeAd: NativeAd?) {
                Log.d(tag, "onNativeShown")
                emitToGodot("native_shown")
            }

            override fun onNativeShowFailed(nativeAd: NativeAd?) {
                Log.e(tag, "onNativeShowFailed")
                emitToGodot("native_show_failed")
            }

            override fun onNativeClicked(nativeAd: NativeAd?) {
                Log.d(tag, "onNativeClicked")
                emitToGodot("native_clicked")
            }

            override fun onNativeExpired() {
                Log.w(tag, "onNativeExpired")
                emitToGodot("native_expired")
            }
        })
    }

    @UsedByGodot
    fun load_banner() {
        cacheAd(Appodeal.BANNER, "banner")
    }

    @UsedByGodot
    fun load_interstitial() {
        cacheAd(Appodeal.INTERSTITIAL, "interstitial")
    }

    @UsedByGodot
    fun load_rewarded() {
        cacheAd(Appodeal.REWARDED_VIDEO, "rewarded")
    }

    @UsedByGodot
    fun load_native(amount: Int) {
        val currentActivity = activity ?: return

        currentActivity.runOnUiThread {
            try {
                if (!initialized) {
                    Log.w(tag, "load_native skipped: SDK is not initialized")
                    return@runOnUiThread
                }

                val safeAmount = amount.coerceIn(1, 5)

                Log.d(tag, "load_native called: amount=$safeAmount")

                Appodeal.cache(currentActivity, Appodeal.NATIVE, safeAmount)

            } catch (e: Throwable) {
                Log.e(tag, "load_native error: ${e.message}", e)
            }
        }
    }

    private fun cacheAd(type: Int, name: String) {
        val currentActivity = activity ?: return

        currentActivity.runOnUiThread {
            try {
                if (!initialized) {
                    Log.w(tag, "load_$name skipped: SDK is not initialized")
                    return@runOnUiThread
                }

                Log.d(tag, "load_$name called")
                Appodeal.cache(currentActivity, type)
            } catch (e: Throwable) {
                Log.e(tag, "load_$name error: ${e.message}", e)
            }
        }
    }

    @UsedByGodot
    fun is_banner_loaded(): Boolean {
        return safeIsLoaded(Appodeal.BANNER)
    }

    @UsedByGodot
    fun is_interstitial_loaded(): Boolean {
        return safeIsLoaded(Appodeal.INTERSTITIAL)
    }

    @UsedByGodot
    fun is_rewarded_loaded(): Boolean {
        return safeIsLoaded(Appodeal.REWARDED_VIDEO)
    }

    @UsedByGodot
    fun is_native_loaded(): Boolean {
        return safeIsLoaded(Appodeal.NATIVE)
    }

    private fun safeIsLoaded(type: Int): Boolean {
        return try {
            Appodeal.isLoaded(type)
        } catch (e: Throwable) {
            false
        }
    }

    @UsedByGodot
    fun get_available_native_count(): Int {
        return try {
            Appodeal.getAvailableNativeAdsCount()
        } catch (e: Throwable) {
            0
        }
    }

    @UsedByGodot
    fun show_banner_at(x: Int, y: Int, width: Int, height: Int) {
        val currentActivity = activity ?: return

        currentActivity.runOnUiThread {
            try {
                Log.d(tag, "show_banner_at called: $x, $y, $width, $height")

                if (!initialized) {
                    Log.w(tag, "show_banner_at skipped: SDK is not initialized")
                    emitToGodot("banner_show_failed")
                    return@runOnUiThread
                }

                if (width <= 0 || height <= 0) {
                    Log.w(tag, "Invalid banner size: $width x $height")
                    emitToGodot("banner_show_failed")
                    return@runOnUiThread
                }

                val root = getRootView(currentActivity)

                if (bannerView == null) {
                    bannerView = Appodeal.getBannerView(currentActivity)
                    root.addView(bannerView)
                }

                updateViewPosition(bannerView, x, y, width, height)
                emitToGodot(
                    "banner_position_updated",
                    x.toLong(),
                    y.toLong(),
                    width.toLong(),
                    height.toLong()
                )

                if (!Appodeal.isLoaded(Appodeal.BANNER)) {
                    Log.d(tag, "Banner is not loaded yet; requesting cache")
                    Appodeal.cache(currentActivity, Appodeal.BANNER)
                    emitToGodot("banner_show_failed")
                    return@runOnUiThread
                }

                val result = Appodeal.show(currentActivity, Appodeal.BANNER_VIEW)
                Log.d(tag, "show_banner_at result=$result")
                if (!result) {
                    emitToGodot("banner_show_failed")
                }
            } catch (e: Throwable) {
                Log.e(tag, "show_banner_at error: ${e.message}", e)
                emitToGodot("banner_show_failed")
            }
        }
    }

    @UsedByGodot
    fun update_banner_position(x: Int, y: Int, width: Int, height: Int) {
        val currentActivity = activity ?: return

        currentActivity.runOnUiThread {
            try {
                if (bannerView == null) {
                    return@runOnUiThread
                }

                if (width <= 0 || height <= 0) {
                    return@runOnUiThread
                }

                updateViewPosition(bannerView, x, y, width, height)
                emitToGodot(
                    "banner_position_updated",
                    x.toLong(),
                    y.toLong(),
                    width.toLong(),
                    height.toLong()
                )
            } catch (e: Throwable) {
                Log.e(tag, "update_banner_position error: ${e.message}", e)
            }
        }
    }

    @UsedByGodot
    fun hide_banner() {
        val currentActivity = activity ?: return

        currentActivity.runOnUiThread {
            try {
                Appodeal.hide(currentActivity, Appodeal.BANNER)

                val parent = bannerView?.parent as? ViewGroup
                parent?.removeView(bannerView)
                bannerView = null

                Log.d(tag, "Banner hidden")
                emitToGodot("banner_hidden")
            } catch (e: Throwable) {
                Log.e(tag, "hide_banner error: ${e.message}", e)
            }
        }
    }

    @UsedByGodot
    fun show_interstitial(placement: String) {
        val currentActivity = activity ?: return

        currentActivity.runOnUiThread {
            try {
                if (!initialized || !Appodeal.isLoaded(Appodeal.INTERSTITIAL)) {
                    Log.w(tag, "Interstitial is not ready")
                    emitToGodot("interstitial_show_failed")
                    return@runOnUiThread
                }

                val result = if (placement.isBlank()) {
                    Appodeal.show(currentActivity, Appodeal.INTERSTITIAL)
                } else {
                    Appodeal.show(currentActivity, Appodeal.INTERSTITIAL, placement)
                }

                Log.d(tag, "show_interstitial result=$result")
                if (!result) {
                    emitToGodot("interstitial_show_failed")
                }
            } catch (e: Throwable) {
                Log.e(tag, "show_interstitial error: ${e.message}", e)
                emitToGodot("interstitial_show_failed")
            }
        }
    }

    @UsedByGodot
    fun show_rewarded(placement: String) {
        val currentActivity = activity ?: return

        currentActivity.runOnUiThread {
            try {
                if (!initialized || !Appodeal.isLoaded(Appodeal.REWARDED_VIDEO)) {
                    Log.w(tag, "Rewarded video is not ready")
                    emitToGodot("rewarded_show_failed")
                    return@runOnUiThread
                }

                val result = if (placement.isBlank()) {
                    Appodeal.show(currentActivity, Appodeal.REWARDED_VIDEO)
                } else {
                    Appodeal.show(currentActivity, Appodeal.REWARDED_VIDEO, placement)
                }

                Log.d(tag, "show_rewarded result=$result")
                if (!result) {
                    emitToGodot("rewarded_show_failed")
                }
            } catch (e: Throwable) {
                Log.e(tag, "show_rewarded error: ${e.message}", e)
                emitToGodot("rewarded_show_failed")
            }
        }
    }

    @UsedByGodot
    fun show_native_at(x: Int, y: Int, width: Int, height: Int, templateType: Int) {
        val currentActivity = activity ?: return

        currentActivity.runOnUiThread {
            try {
                Log.d(tag, "show_native_at called: $x, $y, $width, $height, template=$templateType")

                if (!initialized) {
                    Log.w(tag, "Appodeal is not initialized yet")
                    return@runOnUiThread
                }

                if (width <= 0 || height <= 0) {
                    Log.w(tag, "Invalid native ad size: $width x $height")
                    return@runOnUiThread
                }

                val loaded = Appodeal.isLoaded(Appodeal.NATIVE)
                val count = Appodeal.getAvailableNativeAdsCount()

                Log.d(tag, "Native loaded: $loaded, count: $count")

                if (!loaded || count <= 0) {
                    Log.d(tag, "Native ad is not loaded yet")
                    return@runOnUiThread
                }

                val root = getRootView(currentActivity)

                if (nativeAdView == null || currentNativeTemplateType != templateType) {
                    nativeAdView?.destroy()

                    val parent = nativeAdView?.parent as? ViewGroup
                    parent?.removeView(nativeAdView)

                    nativeAdView = createNativeTemplateView(templateType, currentActivity)
                    currentNativeTemplateType = templateType

                    root.addView(nativeAdView)
                }

                val params = FrameLayout.LayoutParams(width, height)
                params.leftMargin = x
                params.topMargin = y
                params.gravity = Gravity.TOP or Gravity.START

                nativeAdView?.layoutParams = params

                val nativeAds = Appodeal.getNativeAds(1)

                if (nativeAds.isNotEmpty()) {
                    val result = nativeAdView?.registerView(nativeAds[0]) ?: false
                    Log.d(tag, "Native registerView result: $result")
                } else {
                    Log.w(tag, "getNativeAds returned empty list")
                }

            } catch (e: Throwable) {
                Log.e(tag, "show_native_at error: ${e.message}", e)
            }
        }
    }

    @UsedByGodot
    fun update_native_position(x: Int, y: Int, width: Int, height: Int) {
        val currentActivity = activity ?: return

        currentActivity.runOnUiThread {
            try {
                if (nativeAdView == null) {
                    return@runOnUiThread
                }

                if (width <= 0 || height <= 0) {
                    return@runOnUiThread
                }

                updateViewPosition(nativeAdView, x, y, width, height)
                emitToGodot(
                    "native_position_updated",
                    x.toLong(),
                    y.toLong(),
                    width.toLong(),
                    height.toLong()
                )
            } catch (e: Throwable) {
                Log.e(tag, "update_native_position error: ${e.message}", e)
            }
        }
    }

    @UsedByGodot
    fun hide_native() {
        val currentActivity = activity ?: return

        currentActivity.runOnUiThread {
            try {
                nativeAdView?.destroy()

                val parent = nativeAdView?.parent as? ViewGroup
                parent?.removeView(nativeAdView)

                nativeAdView = null

                Log.d(tag, "Native ad hidden")
                emitToGodot("native_hidden")
            } catch (e: Throwable) {
                Log.e(tag, "hide_native error: ${e.message}", e)
            }
        }
    }

    private fun updateViewPosition(view: View?, x: Int, y: Int, width: Int, height: Int) {
        if (view == null) {
            return
        }

        val params = FrameLayout.LayoutParams(width, height)
        params.leftMargin = x
        params.topMargin = y
        params.gravity = Gravity.TOP or Gravity.START

        view.layoutParams = params
        view.requestLayout()
    }

    @UsedByGodot
    fun debug_status(): String {
        return try {
            "initializedFlag=$initialized, " +
                "bannerInitialized=${Appodeal.isInitialized(Appodeal.BANNER)}, " +
                "bannerLoaded=${Appodeal.isLoaded(Appodeal.BANNER)}, " +
                "interstitialInitialized=${Appodeal.isInitialized(Appodeal.INTERSTITIAL)}, " +
                "interstitialLoaded=${Appodeal.isLoaded(Appodeal.INTERSTITIAL)}, " +
                "rewardedInitialized=${Appodeal.isInitialized(Appodeal.REWARDED_VIDEO)}, " +
                "rewardedLoaded=${Appodeal.isLoaded(Appodeal.REWARDED_VIDEO)}, " +
                "nativeInitialized=${Appodeal.isInitialized(Appodeal.NATIVE)}, " +
                "nativeLoaded=${Appodeal.isLoaded(Appodeal.NATIVE)}, " +
                "nativeCount=${Appodeal.getAvailableNativeAdsCount()}"
        } catch (e: Throwable) {
            "debug_status error: ${e.message}"
        }
    }
}
