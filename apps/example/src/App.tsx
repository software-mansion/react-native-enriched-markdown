import { NavigationContainer } from '@react-navigation/native';
import { Stack } from './navigation/Stack';
import HomeScreen from './screens/home/HomeScreen';
import PlaygroundScreen from './screens/playground/PlaygroundScreen';
import TextScreen from './screens/text/TextScreen';
import InputScreen from './screens/input/InputScreen';
import StreamingMarkdownSimulator from './screens/streaming/StreamingMarkdownSimulator';

export default function App() {
  return (
    <NavigationContainer>
      <Stack.Navigator
        initialRouteName="Home"
        screenOptions={{
          headerStyle: {
            backgroundColor: '#BEEBD0',
          },
          headerTintColor: '#001A72',
          headerTitleStyle: {
            fontWeight: 'bold',
          },
          headerBackButtonDisplayMode: 'minimal',
        }}
      >
        <Stack.Screen
          name="Home"
          component={HomeScreen}
          options={{ title: 'Enriched Markdown Examples' }}
        />
        <Stack.Screen
          name="Playground"
          component={PlaygroundScreen}
          options={{ title: 'Playground' }}
        />
        <Stack.Screen
          name="Text"
          component={TextScreen}
          options={{ title: 'Text' }}
        />
        <Stack.Screen
          name="Input"
          component={InputScreen}
          options={{ title: 'Input' }}
        />
        <Stack.Screen
          name="Stream"
          component={StreamingMarkdownSimulator}
          options={{ title: 'Stream' }}
        />
      </Stack.Navigator>
    </NavigationContainer>
  );
}
