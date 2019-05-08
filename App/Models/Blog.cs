using System;

namespace KubernetesDemo.Models
{
    public class Blog
    {
        public string Title { get; set; }
        public string Description { get; set; }
        public DateTime Date { get; set; }
        public string Author { get; set; }
    }
}