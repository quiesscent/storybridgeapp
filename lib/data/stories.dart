class Story {
  final String id;
  final String title;
  final String author;
  final String ageRange;
  final String description;
  final String coverAsset;
  final List<String> pageTexts;
  final String duration;
  final int durationSeconds;
  final bool free;
  final String emoji;
  final String bgColor;
  final List<String> categories;
  final List<String>? pageImages;

  int get pages => pageTexts.length;

  const Story({
    required this.id,
    required this.title,
    required this.author,
    required this.ageRange,
    required this.description,
    required this.coverAsset,
    required this.pageTexts,
    required this.duration,
    required this.durationSeconds,
    this.free = true,
    this.emoji = '📖',
    this.bgColor = '#F5F5DC',
    this.categories = const [],
    this.pageImages,
  });
}

class Category {
  final String id;
  final String label;
  const Category(this.id, this.label);
}

const kCategories = [
  Category('top', 'Top Picks'),
  Category('under1', 'Under 1 min'),
  Category('nursery', 'Nursery Rhymes'),
  Category('bedtime', 'Bedtime Favourites'),
  Category('classic', 'Classic Tales'),
  Category('all', 'All Stories'),
];

const List<Story> kStories = [
  Story(
    id: 'ginger-giraffe',
    title: 'Ginger the Giraffe',
    author: 'T. Albert',
    ageRange: '4–8 years',
    description:
        'Ginger the kind-hearted giraffe leads the savannah animals to safety when drought and fire threaten their home.',
    coverAsset: 'assets/images/ginger/cover.jpg',
    duration: '10 min',
    durationSeconds: 600,
    free: true,
    emoji: '🦒',
    bgColor: '#DCEEFB',
    categories: ['top', 'bedtime', 'classic', 'all'],
    pageTexts: [
      'Once upon a time, there was a giraffe named Ginger.\nGinger lived in Kenya, a country in Africa. Like all giraffes, Ginger had a long neck and long legs. Because she was so tall, she was able to eat food from the very tops of the trees in the savannah.\nThe other animals like zebras and antelopes could not reach where Ginger could reach. But Ginger always found food. She loved the leaves and the new buds of the trees.',
      'One day, Ginger was busy eating her favorite leaves along with some other giraffes. It was a bright sunny day and there was not a cloud in the sky. It had not rained for a long time, so the grass was very dry.\nShe heard a noise down at the bottom of her extra long legs: it was her friend, Mickey the Monkey. He looked very tired.\n"What\'s wrong?" asked Ginger.\nJust then Mickey fell over!',
      'Ginger was also a smart giraffe. She knew what was wrong. Mickey couldn\'t find anything to eat and he was very hungry.\nGinger nibbled some fresh, tender leaves and buds from the top of the tree and dropped them near where Mickey was.\n"Wake up, Mickey!" said Ginger. "I\'ve found something for you to eat."\nSlowly Mickey sat up and ate a little.',
      '"What\'s happened, Mickey? Why are you so hungry?" asked Ginger.\n"It hasn\'t rained for so long and now there\'s no more food," said Mickey.\n"All the zebras and the antelopes and the elephants are getting worried about the dry grass. Some of them are thinking about leaving the savannah and trying to reach the jungle."\n"That\'s a long trip," said Ginger. "Are you going to go with them?"',
      '"I don\'t know," answered Mickey. "What do you think we should do?"\nGinger thought for a while and then suddenly, she had a good idea. "We should go talk to Leo the Lion. He is the smartest animal in the savannah!"\nMickey was too tired to walk, so Ginger invited him to ride on her back.\n"You\'re right. I\'ve got the longest neck in Africa!" laughed Ginger.\nSo they started their journey across the savannah to look for Leo.',
      'Ginger and Mickey were in luck! Leo was sitting up on a rock.\n"Hi, Leo!" they both shouted. Leo had been napping and was a little grumpy when they woke him up. But he was polite.\n"Mickey says that there is no food left on the savannah because it\'s been so dry," said Ginger. "Do you have any ideas?"',
      'Leo thought for a while. He said, "There\'s nothing we can do about the rain. It will come soon, but we can\'t be sure when it will arrive. When the rain comes, all the plants will grow again and there will be lots of food for everybody."\n"The only thing I can think of is for everyone to move closer to the forest. There will be more things to eat there, but it might take days to get there."',
      '"Thank you, Leo," said Ginger. "It\'s probably best if they all try to get closer to the jungle."\nNow they needed to gather all of the animals together to start the long journey. Ginger didn\'t need to go along because she had plenty of food in her high trees. But she was a good friend and wanted to help as much as she could.\nThey walked towards her favorite trees and guess what she and Mickey saw?',
      'All of the animals were already gathered there and waiting for Ginger and Mickey!\n"Eddie the Eagle told us that you\'re taking us to the edge of the jungle," said one of the zebras.\n"Of course, I\'ll help," said Ginger. "I\'m your friend."',
      'So they started on their big journey across the savannah to the jungle. And then they heard it — Thunder!\nSometimes the lightning hits the dry grass and the whole savannah catches fire. And that is exactly what happened.\n"Fire!" they shouted. They could smell it. And now they could see it.\nThe fire was coming towards them!',
      'Ginger had to think fast. Because she was so tall she could see farther than any of the other animals. She stretched her long neck up as far as she could.\n"Quick!" she said. "Everyone run this way."\nAll of the animals followed her and ran as fast as they could. Soon, they were out of danger.\n"Is everyone here?" Ginger asked. All the animals looked around; they were all there.',
      '"I felt a drop," said a zebra. "Me too," said an antelope.\nIt was rain! Finally! Everyone was very happy. The rain put out the fire, filled their watering holes, and made the plants grow again. So they didn\'t have to make that long trip to the jungle.\nSo Ginger, the Giraffe went back to her favorite tree and continued to munch on the leaves and buds.\nThe End.',
    ],
    pageImages: [
      'assets/images/ginger/page_01.jpg',
      'assets/images/ginger/page_02.jpg',
      'assets/images/ginger/page_03.jpg',
      'assets/images/ginger/page_04.jpg',
      'assets/images/ginger/page_05.jpg',
      'assets/images/ginger/page_06.jpg',
      'assets/images/ginger/page_07.jpg',
      'assets/images/ginger/page_08.jpg',
      'assets/images/ginger/page_09.jpg',
      'assets/images/ginger/page_10.jpg',
      'assets/images/ginger/page_11.jpg',
      'assets/images/ginger/page_12.jpg',
    ],
  ),
  Story(
    id: 'twinkle',
    title: 'Twinkle Twinkle Little Star',
    author: 'Jane Taylor',
    ageRange: '0–3 years',
    description: 'A classic lullaby about the wonders of the night sky.',
    coverAsset: 'assets/images/twinkle/cover.png',
    duration: '2 min',
    durationSeconds: 120,
    free: true,
    emoji: '⭐',
    bgColor: '#FFF9C4',
    categories: ['top', 'nursery', 'bedtime', 'all'],
    pageTexts: [
      'Twinkle, twinkle, little star,\nHow I wonder what you are!',
      'Up above the world so high,\nLike a diamond in the sky.',
      'When the blazing sun is gone,\nWhen he nothing shines upon,',
      'Then you show your little light,\nTwinkle, twinkle, all the night.',
    ],
    pageImages: [
      'assets/images/twinkle/page_01.png',
      'assets/images/twinkle/page_02.png',
      'assets/images/twinkle/page_03.png',
      'assets/images/twinkle/page_04.png',
    ],
  ),
  Story(
    id: 'red-riding-hood',
    title: 'Little Red Riding Hood',
    author: 'Charles Perrault',
    ageRange: '4–7 years',
    description: 'The story of a young girl and a big bad wolf in the woods.',
    coverAsset: 'assets/images/red_riding_hood/cover.png',
    duration: '5 min',
    durationSeconds: 300,
    free: false,
    emoji: '🐺',
    bgColor: '#FFCDD2',
    categories: ['classic', 'all'],
    pageTexts: [
      'Once upon a time there was a dear little girl who was loved by everyone who looked at her.',
      'Her grandmother gave her a little cap of red velvet, which suited her so well that she would never wear anything else.',
      'So she was always called Little Red Riding Hood.',
      'One day her mother said: "Come, Little Red Riding Hood, take this cake and wine to your grandmother."',
    ],
    pageImages: [
      'assets/images/red_riding_hood/page_01.png',
      'assets/images/red_riding_hood/page_02.png',
      'assets/images/red_riding_hood/page_03.png',
      'assets/images/red_riding_hood/page_04.png',
    ],
  ),
  Story(
    id: 'three-little-pigs',
    title: 'The Three Little Pigs',
    author: 'Traditional',
    ageRange: '3–6 years',
    description:
        'Three pigs build houses of different materials to stay safe from the wolf.',
    coverAsset: 'assets/images/three_little_pigs/cover.png',
    duration: '4 min',
    durationSeconds: 240,
    free: false,
    emoji: '🐷',
    bgColor: '#E8F5E9',
    categories: ['classic', 'all'],
    pageTexts: [
      'Once upon a time there were three little pigs, and the time came for them to leave home and seek their fortunes.',
      'The first little pig built his house out of straw because it was the easiest thing to do.',
      'The second little pig built his house out of sticks. This was a little bit stronger than a straw house.',
      'The third little pig built his house out of bricks. It took the longest but it was the strongest of all.',
    ],
    pageImages: [
      'assets/images/three_little_pigs/page_01.png',
      'assets/images/three_little_pigs/page_02.png',
      'assets/images/three_little_pigs/page_03.png',
      'assets/images/three_little_pigs/page_04.png',
    ],
  ),

  // ─── Tommy the Turtle's Big Race ─────────────────────────────────────────
  Story(
    id: 'tommy-turtle',
    title: "Tommy the Turtle's Big Race",
    author: 'Storybridge',
    ageRange: '4–7 years',
    description: 'Tommy the slow but determined turtle shows the whole forest that never giving up is the greatest superpower of all.',
    coverAsset: 'assets/story4.jpg',
    duration: '4 min',
    durationSeconds: 240,
    free: true,
    emoji: '🐢',
    bgColor: '#E8F5E9',
    categories: ['top', 'classic', 'all'],
    pageTexts: [
      'Tommy the Turtle lived near a beautiful blue pond. He moved slowly — very, very slowly. All the other animals could run and hop and leap past him.\nBut Tommy had a secret: he never, ever gave up.',
      'One sunny morning, a big race was announced. Every animal in the forest signed up: the rabbit, the fox, the deer, and even the frog.\nTommy signed up too.\n"A turtle in a race?" laughed the rabbit. "You\'ll come last for sure!"\nTommy just smiled and kept walking.',
      'The race began! Whoosh went the rabbit. Zoom went the fox. Leap went the deer.\nBut Tommy put one foot in front of the other — slow and steady — all the way along the winding forest path.',
      'By afternoon, the rabbit had stopped for a nap, sure he had won. The fox had wandered off to eat berries. But Tommy kept going, one step at a time.\nWhen he crossed the finish line, the whole forest cheered.\n"Slow and steady wins the race!" said Tommy with a grin.',
    ],
    pageImages: [
      'assets/story4.jpg',
      'assets/images/twinkle/cover.png',
      'assets/images/red_riding_hood/cover.png',
      'assets/images/three_little_pigs/cover.png',
    ],
  ),

  // ─── Luna's Magic Moon ────────────────────────────────────────────────────
  Story(
    id: 'luna-moon',
    title: "Luna's Magic Moon",
    author: 'Storybridge',
    ageRange: '3–6 years',
    description: 'Luna climbs the tallest hill to find the moon\'s magic, and discovers something much more wonderful than she ever expected.',
    coverAsset: 'assets/story5.jpg',
    duration: '3 min',
    durationSeconds: 180,
    free: true,
    emoji: '🌙',
    bgColor: '#E8EAF6',
    categories: ['top', 'bedtime', 'all'],
    pageTexts: [
      'Luna loved looking up at the moon every night. It glowed soft and white above the rooftops, and Luna was sure it was magic.\nOne night, she decided to climb the tallest hill to get closer to it.',
      'At the top of the hill, Luna found a little rabbit sitting in the moonlight.\n"I\'m looking for the moon\'s magic," Luna told him.\nThe rabbit twitched his ears. "The magic isn\'t up there," he said softly. "It lives in your heart — when you share it with someone."',
      'Luna sat down beside the rabbit and they watched the moon rise higher and higher together. The silver light made everything sparkle — the grass, the trees, even their noses.\n"It IS magic," whispered Luna.',
      'When Luna went home, she felt warm all over. She hadn\'t touched the moon — but she had found something even better: a quiet moment, a new friend, and moonlight shared with someone who cared.\nShe fell asleep with a smile.',
    ],
    pageImages: [
      'assets/story5.jpg',
      'assets/images/red_riding_hood/cover.png',
      'assets/story4.jpg',
      'assets/story6.jpg',
    ],
  ),

  // ─── The Sleepy Little Cloud ──────────────────────────────────────────────
  Story(
    id: 'sleepy-cloud',
    title: 'The Sleepy Little Cloud',
    author: 'Storybridge',
    ageRange: '0–4 years',
    description: 'A fluffy little cloud drifts through the evening sky, sending children everywhere off to dreamland.',
    coverAsset: 'assets/story6.jpg',
    duration: '3 min',
    durationSeconds: 180,
    free: true,
    emoji: '☁️',
    bgColor: '#E3F4FF',
    categories: ['top', 'bedtime', 'under1', 'all'],
    pageTexts: [
      'High in the sky, a little cloud drifted sleepily over the mountains. This cloud was called Cumulus, and every evening he yawned the biggest yawn of all the clouds.\n"Time for sleep," he sighed, floating lower and lower.',
      'Cumulus puffed himself into the biggest, softest, fluffiest shape he could.\nAll the stars came out one by one, twinkling like tiny night-lights. The moon hummed a gentle lullaby just for him.',
      'Down below, the children were climbing into their own beds.\n"Look at that big fluffy cloud," said one little girl, pointing out her window.\n"It looks just like me when I\'m sleepy," she giggled, pulling her blanket up to her chin.',
      'And so the little cloud and all the children went to sleep together. Cumulus drifted quietly through the night sky, soft and peaceful, dreaming of tomorrow\'s sunshine.\nGoodnight, cloud. Goodnight, stars. Goodnight, little ones.',
    ],
    pageImages: [
      'assets/story6.jpg',
      'assets/images/three_little_pigs/cover.png',
      'assets/story5.jpg',
      'assets/story7.jpg',
    ],
  ),

  // ─── Brave Captain Penny ──────────────────────────────────────────────────
  Story(
    id: 'captain-penny',
    title: 'Brave Captain Penny',
    author: 'Storybridge',
    ageRange: '4–7 years',
    description: 'Captain Penny sails her living room carpet on the greatest imaginary adventure ever — and discovers that real courage lives in your imagination.',
    coverAsset: 'assets/story7.jpg',
    duration: '4 min',
    durationSeconds: 240,
    free: true,
    emoji: '⚓',
    bgColor: '#FFF3E0',
    categories: ['top', 'classic', 'all'],
    pageTexts: [
      'Penny had a bright red rain boot, an old pirate hat, and the biggest imagination in the whole street.\nShe was Captain Penny — the greatest explorer who ever sailed the living room carpet!',
      'On the day of her greatest adventure, Captain Penny sailed her cushion-ship across the sea of carpet, past the terrible sofa mountains, and through the dark tunnel under the dining table.\nHer brave crew — her cat Mr Biscuits — sat boldly at the bow.',
      'But then — disaster! Mr Biscuits spotted the dog, and the whole fleet wobbled dangerously.\n"Hold on!" cried Captain Penny. She grabbed the sofa arm, steadied the cushion ship, and rescued Mr Biscuits just in time.\n"We did it!" she cheered.',
      'When Mum called them for lunch, Captain Penny pulled off her pirate hat and smiled.\nReal adventures don\'t need oceans and ships — they just need you. And maybe a cat, and a very good imagination.',
    ],
    pageImages: [
      'assets/story7.jpg',
      'assets/story4.jpg',
      'assets/story6.jpg',
      'assets/story8.jpg',
    ],
  ),
];
