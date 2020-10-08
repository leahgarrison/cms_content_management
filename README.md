[Clickable Demo Link](https://rb-175-content-mgt-system.herokuapp.com/)

# Walk through tutorial project 
# (currently in process - fixing a few bugs)
# Added multiple features (without a tutorial) -
  * Feature: able to make a document copy
  * Feature: new user sign-up/login
  * Feature: able to edit/view old versions of documents


## - Explanation of Differences betweeen My Solutions and Launch School Solutions

1. `Adding an Index Page`
  * My solution does work to display all the file names from the data directory on the homepage. It differs from the LS solution because I am using the #each_child method. The file name is passed to the block, not passing the "." or ".." files. In terms of application functionality, my solution does not let me select specific files from that directoy based on a critera. The #each_child method gets all of the child files.


2. `Handling Requests for Nonexistent Documents`
3. * My solution differs slightly because I check for a non-existent file using my #`get_file_names` method. It checks if the file name requested (from the url path) is found from an array of strings- (file name strings). 
4. Nothing differs for the user. Possible future impact? 
