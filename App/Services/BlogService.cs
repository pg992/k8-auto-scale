using Bogus;
using KubernetesDemo.Models;
using System.Collections.Generic;

namespace KubernetesDemo.Services
{
    public class BlogService
    {
        public IEnumerable<Blog> GetBlogs()
        {
            var totalBlogs = 4;
            var count = 0;

            while (count < totalBlogs)
            {
                var faker = new Faker();
                yield return new Blog
                {
                    Title = faker.Lorem.Sentence(10, 5),
                    Author = faker.Person.FullName,
                    Date = faker.Date.PastOffset().Date,
                    Description = faker.Lorem.Paragraph(1)
                };
                count++;
            }
        }
    }
}