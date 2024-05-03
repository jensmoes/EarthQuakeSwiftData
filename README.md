#  Loading and displaying a large data feed with SwiftData

This is an example inspired by the [original Core Data sample](https://developer.apple.com/documentation/coredata/loading_and_displaying_a_large_data_feed) but using [SwiftData](https://developer.apple.com/documentation/swiftdata)

It loads the monthly earthquake list, creates a secondary context on a background thread with autosave off. Then proceeds to process the batch by insertign all elements and then saving the context.

This is not as efficient as the strategy of using context merging, but does work albeit with a large delay when saving the context.
I have not yet figured out how to fix that short of using 3rd pary packages that enable context merging. But thats besides the point
of doing this using SwiftData :) 

The strategy is to first fetch the data, then decode each element iteratively skipping elements with missing properties (implemented in the decodable data transfer object), appending them to a local array. 
Once all the elements are decoded they are imported into SwiftData using the background context.
When all elements are inserted in the background context it is saved and the main context then picks up the change and updates the UI. 
