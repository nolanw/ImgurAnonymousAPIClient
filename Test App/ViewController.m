//  ViewController.m
//  ImgurHTTPClient
//
//  Public domain. https://github.com/nolanw/ImgurHTTPClient

#import "ViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "ImgurHTTPClient.h"

@interface ViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIPopoverControllerDelegate>

@property (strong, nonatomic) UIImage *image;
@property (strong, nonatomic) NSURL *URL;

@property (strong, nonatomic) NSURLSessionDataTask *uploadTask;

@property (weak, nonatomic) IBOutlet UIButton *chooseImageButton;
@property (weak, nonatomic) IBOutlet UIButton *uploadButton;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIButton *URLButton;
@property (weak, nonatomic) IBOutlet UIView *uploadingHUD;

@end

@implementation ViewController
{
    UIPopoverController *_popover;
}

- (void)updateUserInterface
{
    self.imageView.image = self.image;
    
    self.uploadButton.enabled = !!self.image;
    
    self.uploadingHUD.hidden = !self.uploadTask;
    
    [self.URLButton setTitle:self.URL.absoluteString forState:UIControlStateNormal];
    self.URLButton.enabled = !!self.URL;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self updateUserInterface];
}

- (IBAction)chooseImage:(UIButton *)sender
{
    [self showImagePickerFromButton:sender animated:YES];
}

- (void)showImagePickerAnimated:(BOOL)animated
{
    [self showImagePickerFromButton:self.chooseImageButton animated:animated];
}

- (void)showImagePickerFromButton:(UIButton *)button animated:(BOOL)animated
{
    UIImagePickerController *picker = [UIImagePickerController new];
    picker.delegate = self;
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        _popover = [[UIPopoverController alloc] initWithContentViewController:picker];
        _popover.delegate = self;
        [_popover presentPopoverFromRect:button.bounds inView:button permittedArrowDirections:UIPopoverArrowDirectionAny animated:animated];
    } else {
        [self presentViewController:picker animated:animated completion:nil];
    }
}

- (IBAction)upload:(id)sender
{
    self.URL = nil;
    NSData *data = UIImagePNGRepresentation(self.image);
    __weak __typeof__(self) weakSelf = self;
    self.uploadTask = [[ImgurHTTPClient client] uploadImageData:data withFilename:nil title:nil completionHandler:^(NSURL *imgurURL, NSError *error) {
        __typeof__(self) self = weakSelf;
        self.uploadTask = nil;
        if (error) {
            UIAlertView *alert = [UIAlertView new];
            alert.title = @"Error Uploading Image";
            alert.message = error.localizedDescription;
            [alert addButtonWithTitle:@"OK"];
            [alert show];
        } else {
            self.URL = imgurURL;
        }
        [self updateUserInterface];
    }];
    [self updateUserInterface];
}

- (IBAction)cancelUpload:(id)sender
{
    [self.uploadTask cancel];
}

- (IBAction)openURLInSafari:(id)sender
{
    NSURL *URL = [NSURL URLWithString:[sender titleForState:UIControlStateNormal]];
    [[UIApplication sharedApplication] openURL:URL];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    self.image = info[UIImagePickerControllerEditedImage] ?: info[UIImagePickerControllerOriginalImage];
    self.URL = nil;
    [self updateUserInterface];
    
    if (_popover) {
        [_popover dismissPopoverAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark - UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    if (viewController == navigationController.viewControllers[0]) {
        viewController.title = @"Choose Image";
    }
}

#pragma mark - UIPopoverControllerDelegate

- (void)popoverController:(UIPopoverController *)popoverController willRepositionPopoverToRect:(inout CGRect *)rect inView:(inout UIView **)view
{
    *rect = (*view).bounds;
}

@end
