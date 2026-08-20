# Google Gemini AI Setup

ScreenGate uses Google Gemini AI for:
- Mission verification and star rating
- Personalized Handler feedback
- AI-powered chat conversations
- Mission suggestions based on life goals

## Getting Your API Key

1. Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Sign in with your Google account
3. Click "Get API Key" or "Create API Key"
4. Copy your API key

## Adding the API Key to ScreenGate

1. Open `lib/services/ai_service.dart`
2. Find line 7: `static const String _geminiApiKey = 'YOUR_GEMINI_API_KEY_HERE';`
3. Replace `YOUR_GEMINI_API_KEY_HERE` with your actual API key
4. Save the file

Example:
```dart
static const String _geminiApiKey = 'AIzaSyA1234567890abcdefghijklmnopqrstuvwxyz';
```

## Testing AI Features

The app currently works with mock AI responses as a fallback. Once you add your API key:

1. **Mission Verification**: Complete a mission, upload before/after photos, and tap "Verify Mission"
2. **Handler Chat**: Tap the Handler avatar on the dashboard or go to the chat screen
3. **Mission Suggestions**: Future feature - coming soon!

## API Costs

Google Gemini offers a generous free tier:
- 60 requests per minute
- 1,500 requests per day
- Free for personal use

Perfect for ScreenGate!

## Troubleshooting

If AI features aren't working:
1. Check your API key is correctly pasted
2. Ensure you have internet connection
3. Verify your API key is active in Google AI Studio
4. Check the Debug Console for error messages

The app will automatically fall back to mock responses if the API fails.
