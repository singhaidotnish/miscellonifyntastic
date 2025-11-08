import React, { useState } from 'react';
import { ChevronLeft, ChevronRight } from 'lucide-react';

const NestedCarousel = () => {
  const [activeCategory, setActiveCategory] = useState(0);
  
  // Sample data - Netflix-style content
  const categories = [
    {
      title: "Trending Now",
      items: [
        { id: 1, title: "Action Movie 1", color: "bg-red-500" },
        { id: 2, title: "Drama Series 1", color: "bg-blue-500" },
        { id: 3, title: "Comedy Show 1", color: "bg-green-500" },
        { id: 4, title: "Thriller 1", color: "bg-purple-500" },
        { id: 5, title: "Romance 1", color: "bg-pink-500" },
        { id: 6, title: "Sci-Fi 1", color: "bg-indigo-500" },
      ]
    },
    {
      title: "Action & Adventure",
      items: [
        { id: 7, title: "Action Movie 2", color: "bg-orange-500" },
        { id: 8, title: "Adventure 1", color: "bg-yellow-500" },
        { id: 9, title: "Superhero 1", color: "bg-red-600" },
        { id: 10, title: "War Movie 1", color: "bg-gray-600" },
        { id: 11, title: "Spy Thriller 1", color: "bg-black" },
        { id: 12, title: "Martial Arts 1", color: "bg-red-700" },
      ]
    },
    {
      title: "Comedies",
      items: [
        { id: 13, title: "Sitcom 1", color: "bg-yellow-400" },
        { id: 14, title: "Stand-up 1", color: "bg-green-400" },
        { id: 15, title: "Rom-Com 1", color: "bg-pink-400" },
        { id: 16, title: "Dark Comedy 1", color: "bg-gray-700" },
        { id: 17, title: "Parody 1", color: "bg-blue-400" },
        { id: 18, title: "Sketch Show 1", color: "bg-purple-400" },
      ]
    },
    {
      title: "Documentaries",
      items: [
        { id: 19, title: "Nature Doc 1", color: "bg-green-600" },
        { id: 20, title: "History 1", color: "bg-amber-700" },
        { id: 21, title: "Science 1", color: "bg-cyan-600" },
        { id: 22, title: "Crime 1", color: "bg-red-800" },
        { id: 23, title: "Sports 1", color: "bg-blue-600" },
        { id: 24, title: "Music 1", color: "bg-purple-600" },
      ]
    },
    {
      title: "Horror",
      items: [
        { id: 25, title: "Slasher 1", color: "bg-red-900" },
        { id: 26, title: "Supernatural 1", color: "bg-purple-900" },
        { id: 27, title: "Psychological 1", color: "bg-gray-800" },
        { id: 28, title: "Monster 1", color: "bg-green-900" },
        { id: 29, title: "Found Footage 1", color: "bg-stone-800" },
        { id: 30, title: "Gothic 1", color: "bg-slate-900" },
      ]
    }
  ];

  // State for tracking scroll positions of inner carousels
  const [scrollPositions, setScrollPositions] = useState(
    categories.map(() => 0)
  );

  // Navigate outer carousel (categories)
  const navigateCategory = (direction) => {
    if (direction === 'next' && activeCategory < categories.length - 1) {
      setActiveCategory(activeCategory + 1);
    } else if (direction === 'prev' && activeCategory > 0) {
      setActiveCategory(activeCategory - 1);
    }
  };

  // Navigate inner carousel (items within category)
  const navigateItems = (categoryIndex, direction) => {
    const itemsLength = categories[categoryIndex].items.length;
    const currentPos = scrollPositions[categoryIndex];
    
    let newPos = currentPos;
    if (direction === 'next' && currentPos < itemsLength - 4) {
      newPos = currentPos + 1;
    } else if (direction === 'prev' && currentPos > 0) {
      newPos = currentPos - 1;
    }
    
    const newPositions = [...scrollPositions];
    newPositions[categoryIndex] = newPos;
    setScrollPositions(newPositions);
  };

  return (
    <div className="w-full min-h-screen bg-gray-900 text-white p-8">
      <h1 className="text-4xl font-bold mb-8">Nested Carousel Demo</h1>
      
      {/* Outer Carousel Controls */}
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-2xl font-semibold">
          Category {activeCategory + 1} of {categories.length}
        </h2>
        <div className="flex gap-2">
          <button
            onClick={() => navigateCategory('prev')}
            disabled={activeCategory === 0}
            className="p-2 rounded-full bg-gray-700 hover:bg-gray-600 disabled:opacity-30 disabled:cursor-not-allowed"
          >
            <ChevronLeft size={24} />
          </button>
          <button
            onClick={() => navigateCategory('next')}
            disabled={activeCategory === categories.length - 1}
            className="p-2 rounded-full bg-gray-700 hover:bg-gray-600 disabled:opacity-30 disabled:cursor-not-allowed"
          >
            <ChevronRight size={24} />
          </button>
        </div>
      </div>

      {/* Category Indicators */}
      <div className="flex gap-2 mb-8">
        {categories.map((_, index) => (
          <button
            key={index}
            onClick={() => setActiveCategory(index)}
            className={`h-1 flex-1 rounded transition-all ${
              index === activeCategory ? 'bg-red-600' : 'bg-gray-600'
            }`}
          />
        ))}
      </div>

      {/* Outer Carousel Container */}
      <div className="overflow-hidden">
        <div
          className="flex transition-transform duration-500 ease-in-out"
          style={{ transform: `translateX(-${activeCategory * 100}%)` }}
        >
          {categories.map((category, categoryIndex) => (
            <div key={categoryIndex} className="min-w-full">
              {/* Category Title */}
              <h3 className="text-3xl font-bold mb-6">{category.title}</h3>
              
              {/* Inner Carousel */}
              <div className="relative group">
                {/* Inner Carousel Navigation Buttons */}
                <button
                  onClick={() => navigateItems(categoryIndex, 'prev')}
                  disabled={scrollPositions[categoryIndex] === 0}
                  className="absolute left-0 top-1/2 -translate-y-1/2 z-10 p-2 bg-black/70 hover:bg-black/90 rounded-full opacity-0 group-hover:opacity-100 transition-opacity disabled:opacity-0 disabled:cursor-not-allowed"
                >
                  <ChevronLeft size={32} />
                </button>
                
                <button
                  onClick={() => navigateItems(categoryIndex, 'next')}
                  disabled={scrollPositions[categoryIndex] >= category.items.length - 4}
                  className="absolute right-0 top-1/2 -translate-y-1/2 z-10 p-2 bg-black/70 hover:bg-black/90 rounded-full opacity-0 group-hover:opacity-100 transition-opacity disabled:opacity-0 disabled:cursor-not-allowed"
                >
                  <ChevronRight size={32} />
                </button>

                {/* Items Container */}
                <div className="overflow-hidden">
                  <div
                    className="flex gap-4 transition-transform duration-500 ease-in-out"
                    style={{ 
                      transform: `translateX(-${scrollPositions[categoryIndex] * 25}%)` 
                    }}
                  >
                    {category.items.map((item) => (
                      <div
                        key={item.id}
                        className="min-w-[calc(25%-12px)] aspect-video rounded-lg flex items-center justify-center text-white font-semibold text-lg cursor-pointer transform transition-all hover:scale-105 hover:z-10"
                        style={{ backgroundColor: item.color.replace('bg-', '') }}
                      >
                        <div className={`${item.color} w-full h-full rounded-lg flex items-center justify-center p-4 text-center`}>
                          {item.title}
                        </div>
                      </div>
                    ))}
                  </div>
                </div>

                {/* Inner Carousel Indicators */}
                <div className="flex gap-1 mt-4 justify-center">
                  {Array.from({ length: Math.max(0, category.items.length - 3) }).map((_, index) => (
                    <div
                      key={index}
                      className={`h-1 w-8 rounded transition-all ${
                        index === scrollPositions[categoryIndex] 
                          ? 'bg-white' 
                          : 'bg-gray-600'
                      }`}
                    />
                  ))}
                </div>
              </div>

              {/* Spacing between categories */}
              <div className="mb-12" />
            </div>
          ))}
        </div>
      </div>

      {/* Instructions */}
      <div className="mt-12 p-6 bg-gray-800 rounded-lg">
        <h3 className="text-xl font-bold mb-4">How to Use:</h3>
        <ul className="space-y-2 text-gray-300">
          <li>• <strong>Outer Carousel:</strong> Use the top navigation buttons or click category indicators to switch between categories</li>
          <li>• <strong>Inner Carousel:</strong> Hover over each category to reveal left/right arrows for scrolling through items</li>
          <li>• <strong>Visual Feedback:</strong> Active indicators show your position in both carousels</li>
          <li>• <strong>Hover Effects:</strong> Items scale up when you hover over them</li>
        </ul>
      </div>

      {/* Technical Details */}
      <div className="mt-6 p-6 bg-gray-800 rounded-lg">
        <h3 className="text-xl font-bold mb-4">Technical Implementation:</h3>
        <ul className="space-y-2 text-gray-300">
          <li>• <strong>Outer Carousel:</strong> Uses CSS transform translateX with percentage-based positioning</li>
          <li>• <strong>Inner Carousels:</strong> Each maintains independent scroll state</li>
          <li>• <strong>State Management:</strong> Array of scroll positions (one per category)</li>
          <li>• <strong>Responsive:</strong> Shows 4 items at once, scrolls one at a time</li>
          <li>• <strong>Smooth Animations:</strong> CSS transitions for all movements</li>
        </ul>
      </div>
    </div>
  );
};

export default NestedCarousel;