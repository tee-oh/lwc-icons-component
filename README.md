Developed by Hermia Lam, Teo Popa, and Zach Horton.

# lwc-icons-component
The “Icons” Lighting Web Component (LWC) is intended to provide a scalable, alternative to using standard formula fields (limited by character/byte sizes) to assess record values and display an image (icon/flag) on a Salesforce record. If an organization has a need to evaluate the value of a record field (or several record fields in combination), and display an image (icon/flag) that visually summarizes the state of the record for a user, then they can add the “Icons” component to a flexipage and configure Custom Metadata Type records to declare conditions to show an image under.

Additionally, the “Icons” component can be configured to “inherit” and display images (icons/flags) that live on parent records. This is configured for several standard objects, however, if you want to inherit for other standard or custom objects you will need to modify the component code to suit your needs.

# Basic Setup
1. Create a static resource named "Icons" and upload a zipped version of a folder that houses the properly-sized images to be displayed.
![1_Static Resource](https://user-images.githubusercontent.com/43816466/168383434-7e033ff2-262b-4534-b1f3-5973228f46ad.JPG)

2. Create an "Icon" custom metadata type record that points to an image from the static resource file. For the file type suffix, verify in the properties of the image file whether to use .jpg, .JPG, .png, .PNG, etc. NOTE: This file extension is case sensitive. <img width="1001" height="463" alt="2_Icon_CMT_2025" src="https://github.com/user-attachments/assets/b21008de-9c30-4ad1-8f3e-075b0f943c76" />

4. Create an "Icon Condition Group" custom metadata type record that will signal if the conditions involved in displaying the image will be evaluated as "AND" conditions (inclusive), or "OR" conditions (exclusive). NOTE: There is currently no support for a combination of "AND" and "OR" conditions. Condition groups must be one or the other or they will not evaluate correctly. If there is only one condition to display an image, then create a grouping record and select "AND" as the default. In a comma-separated list with no spaces, add in the API name of the object(s) that the image may be displayed on. Essentially, this makes the image "available" to these objects. <img width="999" height="488" alt="3_Icon_Condition_Group_CMT_2025" src="https://github.com/user-attachments/assets/bfef0694-b36a-4676-a6b5-a046d68baedb" />

5. Create an "Icon Condition" custom metadata type record to capture the condition(s) under which an image should be displayed on a record. <img width="997" height="425" alt="4_Icon_Condition_CMT_2025" src="https://github.com/user-attachments/assets/f6aac0bf-2da1-42a0-913a-bc174dadcec8" />

6. Add the "Icons" component to the record lightning page (flexipage) that the image will be displayed on. You will not need to set any properties on the component unless you want to inherit icons from parent records (see "Inheriting Icons" section). <img width="1226" height="706" alt="5_Icons_Flexipage_2025" src="https://github.com/user-attachments/assets/25a825b9-7cc2-4fc8-89f0-ceacfa61acee" />

7. If configured correctly, the component will read the value(s) of the record for the stated condition(s) and display the image if the condition(s) are met. <img width="1207" height="512" alt="6_Icons_Component_2025" src="https://github.com/user-attachments/assets/05c3dcd9-354f-426d-b4cd-ac8a86f9ae4d" />

# Inheriting Icons

1. The "Icons" component can be configured to inherit and display icons from a parent record(s). In order to inherit an icon from a parent record, on the lightning page component properties, enter the API name of the relationship field on the object that you want to navigate through to find parent icons.
![1_Inheriting_Icons](https://user-images.githubusercontent.com/43816466/183451673-7d185514-d46b-4424-8d97-6e708afd7c0a.PNG)
![2_Inheriting_Icons](https://user-images.githubusercontent.com/43816466/183453879-dd77cca9-ef10-44e8-99ed-70cabd6c8140.PNG)
